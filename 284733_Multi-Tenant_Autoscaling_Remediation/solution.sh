#!/bin/bash
# solution-hpa-lab.sh
# Applies the complete remediation for the FinFlow payment-processor autoscaling stack.
# Run as: bash solution-hpa-lab.sh

set -euo pipefail

BASE_DIR="/home/user/finflow-solution"
NAMESPACE="finflow-prod"

mkdir -p "${BASE_DIR}"

# --------------------------------------------------
# Deployment (FIXED)
#
# Fix 1: processor — requests added beneath the existing limits.
#         Requests must stay below limits. Setup script uses:
#           limits.cpu: 300m  / limits.memory: 256Mi
#         So requests are set to:
#           requests.cpu: 100m / requests.memory: 128Mi
#
# Fix 2: audit-logger — full resource block added.
#         Small values that fit comfortably on lab-sized nodes.
# --------------------------------------------------
function apply_fixed_deployment() {
    cat > "${BASE_DIR}/payment-processor-deployment-fixed.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-processor
  namespace: finflow-prod
  labels:
    app: payment-processor
    tier: backend
    version: v2.4.1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-processor
  template:
    metadata:
      labels:
        app: payment-processor
        tier: backend
    spec:
      containers:

      - name: processor
        image: nginx:alpine
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 9090
          name: metrics
        env:
        - name: APP_ENV
          value: "production"
        # FIX 1: requests added — HPA can now compute utilization%.
        # Kept well below the limits already set by the setup script
        # (cpu: 300m / memory: 256Mi) so pods schedule on small nodes.
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 300m
            memory: 256Mi

      - name: audit-logger
        image: busybox:latest
        command: ["sh","-c","while true; do echo audit-$(date +%s); sleep 5; done"]
        env:
        - name: LOG_LEVEL
          value: "info"
        # FIX 2: full resource block — sidecar requests are now included
        # in the HPA denominator so utilization calculations are correct.
        resources:
          requests:
            cpu: 20m
            memory: 32Mi
          limits:
            cpu: 50m
            memory: 64Mi
EOF

    echo "Applying fixed Deployment..."
    kubectl apply -f "${BASE_DIR}/payment-processor-deployment-fixed.yaml"

    echo "Waiting for rollout..."
    kubectl rollout status deployment/payment-processor \
        -n "${NAMESPACE}" --timeout=120s || true
}

# --------------------------------------------------
# HPA (FIXED)
#
# Fix 3:  minReplicas 1  → 3   (HA baseline)
# Fix 4:  maxReplicas 50 → 15  (cluster guardrail)
# Fix 5:  CPU target 25% → 70% (efficient utilization)
# Fix 6:  Memory metric added at 80%
# Fix 7:  Custom Object metric pending_transactions, threshold 300
# Fix 10: scaleDown stabilizationWindowSeconds 0 → 300 (no flapping)
# --------------------------------------------------
function apply_fixed_hpa() {
    cat > "${BASE_DIR}/payment-processor-hpa-fixed.yaml" <<'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: payment-processor-hpa
  namespace: finflow-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: payment-processor

  # FIX 3: 3 replicas — no single point of failure
  minReplicas: 3

  # FIX 4: 15 is a safe upper bound for this cluster size
  maxReplicas: 15

  metrics:
  # FIX 5: 70% CPU — efficient utilization without saturation risk
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70

  # FIX 6: Memory metric — detects heap and buffer pressure
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80

  # FIX 7: Queue-depth metric — proactive scale-out before CPU spikes
  - type: Object
    object:
      metric:
        name: pending_transactions
      describedObject:
        apiVersion: v1
        kind: Service
        name: payment-queue
      target:
        type: Value
        value: "300"

  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Pods
        value: 4
        periodSeconds: 15
      - type: Percent
        value: 100
        periodSeconds: 15
      selectPolicy: Max

    scaleDown:
      # FIX 10: 5-minute window prevents scale-down between short bursts
      stabilizationWindowSeconds: 300
      policies:
      - type: Pods
        value: 2
        periodSeconds: 60
      - type: Percent
        value: 25
        periodSeconds: 60
      selectPolicy: Min
EOF

    echo "Applying fixed HPA..."
    kubectl apply -f "${BASE_DIR}/payment-processor-hpa-fixed.yaml"
}

# --------------------------------------------------
# VPA (FIXED)
#
# Fix 8: updateMode Auto → Off
# VPA keeps collecting right-sizing recommendations but will
# never evict pods or conflict with HPA's scale-out decisions.
# --------------------------------------------------
function apply_fixed_vpa() {
    if ! kubectl api-resources 2>/dev/null | grep -q "verticalpodautoscalers"; then
        echo "VPA CRD not available — skipping VPA fix"
        return
    fi

    if ! kubectl get vpa payment-processor-vpa -n "${NAMESPACE}" &>/dev/null; then
        echo "VPA 'payment-processor-vpa' not found — skipping VPA fix"
        return
    fi

    cat > "${BASE_DIR}/payment-processor-vpa-fixed.yaml" <<'EOF'
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: payment-processor-vpa
  namespace: finflow-prod
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: payment-processor
  updatePolicy:
    # FIX 8: Off — recommendations visible, no evictions triggered
    updateMode: "Off"
  resourcePolicy:
    containerPolicies:
    - containerName: processor
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 300m
        memory: 256Mi
EOF

    echo "Applying fixed VPA (updateMode: Off)..."
    kubectl apply -f "${BASE_DIR}/payment-processor-vpa-fixed.yaml"
}

# --------------------------------------------------
# PodDisruptionBudget (NEW)
#
# Fix 9: minAvailable: 2 — at least two pods must survive any
# voluntary disruption (node drain, rolling update).
# With minReplicas: 3, at most one pod is ever disrupted at a time.
# --------------------------------------------------
function apply_pdb() {
    cat > "${BASE_DIR}/payment-processor-pdb.yaml" <<'EOF'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: payment-processor-pdb
  namespace: finflow-prod
  labels:
    app: payment-processor
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: payment-processor
EOF

    echo "Applying PodDisruptionBudget..."
    kubectl apply -f "${BASE_DIR}/payment-processor-pdb.yaml"
}

# --------------------------------------------------
# Verify
# --------------------------------------------------
function verify() {
    echo ""
    echo "============================================================"
    echo "  VERIFICATION"
    echo "============================================================"

    echo ""
    echo "--- Pods ---"
    kubectl get pods -n "${NAMESPACE}" -l app=payment-processor

    echo ""
    echo "--- HPA ---"
    kubectl get hpa payment-processor-hpa -n "${NAMESPACE}"

    echo ""
    echo "--- VPA (if available) ---"
    if kubectl api-resources 2>/dev/null | grep -q "verticalpodautoscalers"; then
        kubectl get vpa -n "${NAMESPACE}" 2>/dev/null || echo "  (none found)"
    else
        echo "  VPA CRD not available"
    fi

    echo ""
    echo "--- PodDisruptionBudget ---"
    kubectl get pdb -n "${NAMESPACE}"
}

# --------------------------------------------------
# Summary
# --------------------------------------------------
function print_summary() {
    echo ""
    echo "============================================================"
    echo "  REMEDIATION COMPLETE"
    echo "============================================================"
    echo ""
    echo "  Fix 1  processor requests added       cpu: 100m, memory: 128Mi"
    echo "  Fix 2  audit-logger requests added     cpu: 20m,  memory: 32Mi"
    echo "  Fix 3  minReplicas: 1  → 3"
    echo "  Fix 4  maxReplicas: 50 → 15"
    echo "  Fix 5  CPU target:  25% → 70%"
    echo "  Fix 6  Memory metric added             target: 80%"
    echo "  Fix 7  pending_transactions metric     threshold: 300"
    echo "  Fix 8  VPA updateMode: Auto → Off"
    echo "  Fix 9  PDB created                     minAvailable: 2"
    echo "  Fix 10 scaleDown stabilization: 0s → 300s"
    echo ""
    echo "  Autoscaling behaviour:"
    echo "    Always >= 3 replicas running"
    echo "    Scales up fast  : up to 4 pods or 100% per 15s"
    echo "    Scales down slow: max 2 pods or 25% per 60s, after 5m window"
    echo "    Triggers on     : CPU > 70%, memory > 80%, queue > 300"
    echo "    VPA advises right-sizing without evicting pods"
    echo "    Rolling updates always leave >= 2 pods running"
    echo "============================================================"
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "============================================================"
    echo "  FINFLOW HPA REMEDIATION — APPLYING SOLUTION"
    echo "============================================================"
    echo ""

    echo "[1/4] Fixing Deployment..."
    apply_fixed_deployment

    echo ""
    echo "[2/4] Fixing HPA..."
    apply_fixed_hpa

    echo ""
    echo "[3/4] Fixing VPA..."
    apply_fixed_vpa

    echo ""
    echo "[4/4] Creating PodDisruptionBudget..."
    apply_pdb

    verify
    print_summary
}

main