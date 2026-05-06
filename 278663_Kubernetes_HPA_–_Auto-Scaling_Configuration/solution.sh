#!/bin/bash
# solution-hpa-lab.sh
# Fixes all HPA misconfigurations
# Creates properly configured autoscaling for shop API

set -euo pipefail

BASE_DIR="$HOME/ecommerce-solution"
NAMESPACE="ecommerce-prod"

NS_FILE="${BASE_DIR}/namespace.yaml"
DEPLOY_FILE="${BASE_DIR}/shop-api-deployment-fixed.yaml"
SVC_FILE="${BASE_DIR}/shop-api-service.yaml"
HPA_FILE="${BASE_DIR}/shop-api-hpa-fixed.yaml"

mkdir -p "$BASE_DIR"

# --------------------------------------------------
# Namespace
# --------------------------------------------------
function create_namespace_yaml() {
    cat > "$NS_FILE" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: ecommerce-prod
  labels:
    environment: production
    team: platform
EOF
}

# --------------------------------------------------
# Deployment (FIXED - WITH RESOURCE REQUESTS)
# --------------------------------------------------
function create_fixed_deployment_yaml() {
    cat > "$DEPLOY_FILE" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-api
  namespace: ecommerce-prod
  labels:
    app: shop-api
    tier: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: shop-api
  template:
    metadata:
      labels:
        app: shop-api
        tier: backend
    spec:
      containers:
      - name: api
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        
        # FIXED: Added resource requests for HPA to work
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
EOF
}

# --------------------------------------------------
# Service
# --------------------------------------------------
function create_service_yaml() {
    cat > "$SVC_FILE" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: shop-api
  namespace: ecommerce-prod
  labels:
    app: shop-api
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: shop-api
EOF
}

# --------------------------------------------------
# HPA (FIXED - ALL ISSUES RESOLVED)
# --------------------------------------------------
function create_fixed_hpa_yaml() {
    cat > "$HPA_FILE" <<'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: shop-api-hpa
  namespace: ecommerce-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: shop-api
  
  # FIX 1: Set minReplicas to 2 for high availability
  minReplicas: 2
  
  # FIX 2: Set reasonable maxReplicas to prevent runaway scaling
  maxReplicas: 10
  
  metrics:
  # FIX 3: CPU target set to 70% (efficient utilization)
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  
  # FIX 4: Added memory metric
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  
  # FIX 5: Added scale behavior for stability
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 15
      - type: Pods
        value: 2
        periodSeconds: 15
      selectPolicy: Min
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
EOF
}

# --------------------------------------------------
# Ensure Namespace Exists
# --------------------------------------------------
function ensure_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo "Creating namespace $NAMESPACE..."
        kubectl apply -f "$NS_FILE"
    else
        echo "Namespace $NAMESPACE already exists."
    fi
}

# --------------------------------------------------
# Apply Resources
# --------------------------------------------------
function apply_resources() {
    echo ""
    echo "Applying Service..."
    kubectl apply -f "$SVC_FILE"
    
    echo ""
    echo "Applying fixed Deployment with resource requests..."
    kubectl apply -f "$DEPLOY_FILE"
    
    echo ""
    echo "Applying fixed HPA..."
    kubectl apply -f "$HPA_FILE"
}

# --------------------------------------------------
# Verify Deployment
# --------------------------------------------------
function verify_deployment() {
    echo ""
    echo "Waiting for deployment rollout..."
    kubectl rollout status deployment/shop-api -n "$NAMESPACE" --timeout=120s
    
    echo ""
    echo "Verifying pods are running..."
    kubectl get pods -n "$NAMESPACE" -l app=shop-api
}

# --------------------------------------------------
# Verify HPA
# --------------------------------------------------
function verify_hpa() {
    echo ""
    echo "=========================================="
    echo "HPA VERIFICATION"
    echo "=========================================="
    
    echo ""
    echo "Waiting for HPA to collect metrics (this may take 1-2 minutes)..."
    sleep 15
    
    echo ""
    echo "HPA Status:"
    kubectl get hpa shop-api-hpa -n "$NAMESPACE"
    
    echo ""
    echo "HPA Details:"
    kubectl describe hpa shop-api-hpa -n "$NAMESPACE"
    
    echo ""
    echo "Current Pods:"
    kubectl get pods -n "$NAMESPACE" -l app=shop-api -o wide
}

# --------------------------------------------------
# Test Autoscaling (Optional Load Generation)
# --------------------------------------------------
function test_autoscaling() {
    echo ""
    echo "=========================================="
    echo "AUTOSCALING TEST (OPTIONAL)"
    echo "=========================================="
    echo ""
    echo "To test autoscaling, you can generate load:"
    echo ""
    echo "1. Install load generator:"
    echo "   kubectl run -it --rm load-generator --image=busybox --restart=Never -n $NAMESPACE -- /bin/sh"
    echo ""
    echo "2. Inside the pod, run:"
    echo "   while true; do wget -q -O- http://shop-api; done"
    echo ""
    echo "3. Watch HPA scale up:"
    echo "   kubectl get hpa shop-api-hpa -n $NAMESPACE -w"
    echo ""
    echo "4. Stop load and watch scale down (takes 5 minutes due to stabilization)"
    echo ""
}

# --------------------------------------------------
# Configuration Summary
# --------------------------------------------------
function show_summary() {
    echo ""
    echo "=========================================="
    echo "HPA CONFIGURATION SUMMARY"
    echo "=========================================="
    echo ""
    echo "All fixes applied:"
    echo "  ✓ Deployment has resource requests (cpu: 100m, memory: 128Mi)"
    echo "  ✓ minReplicas: 2 (high availability)"
    echo "  ✓ maxReplicas: 10 (prevents runaway scaling)"
    echo "  ✓ CPU target: 70% (efficient utilization)"
    echo "  ✓ Memory target: 80% (monitors memory usage)"
    echo "  ✓ Scale behavior configured (prevents flapping)"
    echo ""
    echo "Autoscaling behavior:"
    echo "  - Maintains minimum 2 replicas always"
    echo "  - Scales up when CPU > 70% OR memory > 80%"
    echo "  - Scales up quickly (can add up to 4 pods every 15s)"
    echo "  - Scales down slowly (waits 5 min, removes max 50% every 15s)"
    echo "  - Maximum 10 replicas to protect cluster resources"
    echo ""
    echo "Benefits:"
    echo "  - High availability (always 2+ replicas)"
    echo "  - Efficient resource usage (70-80% targets)"
    echo "  - Fast response to traffic spikes"
    echo "  - Stable scaling (no rapid up/down)"
    echo "  - Cost control (max 10 replicas)"
    echo ""
    echo "=========================================="
    echo "AUTOSCALING READY"
    echo "=========================================="
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "=========================================="
    echo "FIXING HPA MISCONFIGURATIONS"
    echo "=========================================="
    echo ""
    echo "Creating solution files in: $BASE_DIR"
    echo ""
    
    create_namespace_yaml
    create_fixed_deployment_yaml
    create_service_yaml
    create_fixed_hpa_yaml
    
    echo "Solution files created:"
    echo "  $NS_FILE"
    echo "  $DEPLOY_FILE"
    echo "  $SVC_FILE"
    echo "  $HPA_FILE"
    echo ""
    
    ensure_namespace
    apply_resources
    verify_deployment
    verify_hpa
    test_autoscaling
    show_summary
}

main