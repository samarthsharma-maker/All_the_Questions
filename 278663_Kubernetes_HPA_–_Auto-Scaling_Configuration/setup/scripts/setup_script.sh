#!/bin/bash

set -euo pipefail

BASE_DIR="/home/user/ecommerce-lab"
NAMESPACE="ecommerce-prod"

NS_FILE="${BASE_DIR}/namespace.yaml"
DEPLOY_FILE="${BASE_DIR}/shop-api-deployment.yaml"
SVC_FILE="${BASE_DIR}/shop-api-service.yaml"
HPA_FILE="${BASE_DIR}/shop-api-hpa.yaml"

# --------------------------------------------------
# Utilities
# --------------------------------------------------
function create_base_directory() {
    mkdir -p "${BASE_DIR}"
}

# --------------------------------------------------
# Namespace Manifest
# --------------------------------------------------
function create_namespace_yaml() {
    cat > "${NS_FILE}" <<'EOF'
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
# Deployment Manifest (MISSING RESOURCE REQUESTS)
# HPA cannot work without resource requests!
# --------------------------------------------------
function create_broken_deployment_yaml() {
    cat > "${DEPLOY_FILE}" <<'EOF'
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
        
        # PROBLEM: Missing resource requests!
        # HPA needs CPU/memory requests to calculate metrics
        # Without requests, HPA shows "unknown" and cannot scale
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          # requests: MISSING!
EOF
}

# --------------------------------------------------
# Service Manifest
# --------------------------------------------------
function create_service_yaml() {
    cat > "${SVC_FILE}" <<'EOF'
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
# HPA Manifest (MISCONFIGURED)
# Multiple issues with HPA configuration
# --------------------------------------------------
function create_broken_hpa_yaml() {
    cat > "${HPA_FILE}" <<'EOF'
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
  
  # PROBLEM 1: minReplicas too low (should be at least 2 for HA)
  minReplicas: 1
  
  # PROBLEM 2: maxReplicas too high (no upper bound protection)
  maxReplicas: 100
  
  metrics:
  # PROBLEM 3: CPU target too low (will scale up too aggressively)
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 30
  
  # PROBLEM 4: Missing memory metric (should consider both CPU and memory)
  
  # PROBLEM 5: No scale behavior configuration (uses default aggressive scaling)
EOF
}

# --------------------------------------------------
# Permissions & Instructions
# --------------------------------------------------
function finalize_lab_setup() {
    chown -R user:user "${BASE_DIR}" 2>/dev/null || true

    echo
    echo "=========================================="
    echo "E-COMMERCE API SCALING CRISIS"
    echo "=========================================="
    echo
    echo "Lab manifests created:"
    echo "  ${NS_FILE}"
    echo "  ${DEPLOY_FILE}"
    echo "  ${SVC_FILE}"
    echo "  ${HPA_FILE}"
    echo
    echo "Apply the lab with:"
    echo "  kubectl apply -f ${BASE_DIR}"
    echo
    echo "=========================================="
    echo "CRITICAL ISSUES:"
    echo "=========================================="
    echo
    echo "The shop API HPA has multiple problems:"
    echo
    echo "Issue 1: DEPLOYMENT MISSING RESOURCE REQUESTS"
    echo "  - HPA cannot calculate CPU/memory utilization"
    echo "  - Metrics will show 'unknown'"
    echo "  - Autoscaling will NOT work"
    echo "  - Must add: requests.cpu and requests.memory"
    echo
    echo "Issue 2: MINREPLICAS TOO LOW"
    echo "  - minReplicas: 1 (no high availability)"
    echo "  - Single pod = single point of failure"
    echo "  - Should be at least 2 for production"
    echo
    echo "Issue 3: MAXREPLICAS TOO HIGH"
    echo "  - maxReplicas: 100 (no upper limit protection)"
    echo "  - Could exhaust cluster resources"
    echo "  - Cost explosion during traffic spike"
    echo "  - Should be reasonable limit (e.g., 10)"
    echo
    echo "Issue 4: CPU TARGET TOO LOW"
    echo "  - Target: 30% CPU (too aggressive)"
    echo "  - Will scale up too quickly"
    echo "  - Wastes resources"
    echo "  - Should be 70-80% for efficiency"
    echo
    echo "Issue 5: MISSING MEMORY METRIC"
    echo "  - Only monitoring CPU"
    echo "  - Memory-intensive workloads won't scale properly"
    echo "  - Should monitor both CPU and memory"
    echo
    echo "Issue 6: NO SCALE BEHAVIOR"
    echo "  - Uses default aggressive scaling"
    echo "  - Can cause rapid scale up/down (flapping)"
    echo "  - Should configure stabilization windows"
    echo
    echo "=========================================="
    echo "LEARNER TASKS:"
    echo "=========================================="
    echo
    echo "1. Fix Deployment - Add resource requests:"
    echo "   requests:"
    echo "     cpu: 100m"
    echo "     memory: 128Mi"
    echo
    echo "2. Fix HPA minReplicas: 2 (for HA)"
    echo
    echo "3. Fix HPA maxReplicas: 10 (reasonable limit)"
    echo
    echo "4. Fix CPU target: 70% (efficient utilization)"
    echo
    echo "5. Add memory metric with 80% target"
    echo
    echo "6. Add scale behavior (optional for stability)"
    echo
    echo "Expected outcome:"
    echo "  ✓ HPA shows CPU/memory metrics (not unknown)"
    echo "  ✓ Minimum 2 replicas for high availability"
    echo "  ✓ Maximum 10 replicas to prevent runaway scaling"
    echo "  ✓ Scales at 70% CPU or 80% memory"
    echo "  ✓ Both CPU and memory monitored"
    echo "  ✓ Autoscaling works correctly"
    echo
    echo "=========================================="
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    create_base_directory
    create_namespace_yaml
    create_broken_deployment_yaml
    create_service_yaml
    create_broken_hpa_yaml
    finalize_lab_setup
}

main