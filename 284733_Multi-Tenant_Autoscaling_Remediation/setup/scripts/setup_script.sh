#!/bin/bash
# setup-hpa-lab.sh
# Creates the broken FinFlow payment-processor environment for the HPA remediation lab.

set -euo pipefail

HOME_DIR="/home/user"
BASE_DIR="/home/user/finflow-lab"
NAMESPACE="finflow-prod"
mkdir -p "${BASE_DIR}"

function create_namespace() {
cat > "${BASE_DIR}/namespace.yaml" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: finflow-prod
  labels:
    environment: production
    team: payments
    compliance: pci-dss
EOF

kubectl apply -f "${BASE_DIR}/namespace.yaml"
}

function create_broken_deployment() {

cat > "${BASE_DIR}/payment-processor-deployment.yaml" <<'EOF'
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
  replicas: 2
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

        # Limits reduced so pods can schedule on small lab nodes
        resources:
          limits:
            cpu: 300m
            memory: 256Mi
          # requests intentionally missing

      - name: audit-logger
        image: busybox:latest
        command: ["sh","-c","while true; do echo audit-$(date +%s); sleep 5; done"]
        env:
        - name: LOG_LEVEL
          value: "info"

        # Intentionally no resource block
        # Learner must add requests
EOF

kubectl apply -f "${BASE_DIR}/payment-processor-deployment.yaml"
}

function create_services() {

cat > "${BASE_DIR}/payment-processor-service.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: payment-processor
  namespace: finflow-prod
  labels:
    app: payment-processor
spec:
  type: ClusterIP
  selector:
    app: payment-processor
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  - name: metrics
    port: 9090
    targetPort: 9090
---
apiVersion: v1
kind: Service
metadata:
  name: payment-queue
  namespace: finflow-prod
  labels:
    app: payment-queue
spec:
  type: ClusterIP
  selector:
    app: payment-queue
  ports:
  - name: http
    port: 8080
    targetPort: 8080
EOF

kubectl apply -f "${BASE_DIR}/payment-processor-service.yaml"
}


function create_broken_hpa() {

cat > "${BASE_DIR}/payment-processor-hpa.yaml" <<'EOF'
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

  minReplicas: 1
  maxReplicas: 50

  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 25

  behavior:
    scaleDown:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      selectPolicy: Max
EOF

kubectl apply -f "${BASE_DIR}/payment-processor-hpa.yaml"
}

function create_broken_vpa() {

if kubectl api-resources 2>/dev/null | grep -q verticalpodautoscalers; then

cat > "${BASE_DIR}/payment-processor-vpa.yaml" <<'EOF'
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
    updateMode: "Auto"
EOF

kubectl apply -f "${BASE_DIR}/payment-processor-vpa.yaml"
echo "  VPA created (Auto mode)"

else
echo "  VPA CRD not available — skipping VPA creation"
touch "${BASE_DIR}/.vpa_not_available"
fi
}

function note_missing_pdb() { echo "  PodDisruptionBudget intentionally NOT created"; }
function wait_for_rollout() { kubectl rollout status deployment/payment-processor -n "${NAMESPACE}" --timeout=90s || true; }


function main() {

echo "Setting up FinFlow HPA Remediation Lab..."
echo ""

echo "[1/6] Creating namespace..."
create_namespace

echo "[2/6] Creating deployment..."
create_broken_deployment

echo "[3/6] Creating services..."
create_services

echo "[4/6] Creating HPA..."
create_broken_hpa

echo "[5/6] Creating VPA..."
create_broken_vpa

echo "[6/6] PDB intentionally missing..."
note_missing_pdb

wait_for_rollout

chown -R user:user "${BASE_DIR}" 2>/dev/null || true

echo ""
echo "Environment ready."
echo "Fix the autoscaling stack in namespace: finflow-prod"
}

main