#!/bin/bash


set -euo pipefail

BASE_DIR="/home/user/financeflow-lab"
NAMESPACE_PROD="production"
NAMESPACE_STAGE="staging"
NAMESPACE_DEV="development"

NS_PROD_FILE="${BASE_DIR}/namespace-production.yaml"
NS_STAGE_FILE="${BASE_DIR}/namespace-staging.yaml"
NS_DEV_FILE="${BASE_DIR}/namespace-development.yaml"
CLUSTER_ADMIN_BINDING_FILE="${BASE_DIR}/developer-admin-binding.yaml"
SAMPLE_APP_FILE="${BASE_DIR}/sample-production-app.yaml"


function create_base_directory() {mkdir -p "${BASE_DIR}"; }


function create_namespace_yamls() {
    cat > "${NS_PROD_FILE}" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
    security: critical
EOF

    # Staging namespace
    cat > "${NS_STAGE_FILE}" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
EOF

    # Development namespace
    cat > "${NS_DEV_FILE}" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: development
EOF
}

function create_insecure_cluster_admin_binding() {
    cat > "${CLUSTER_ADMIN_BINDING_FILE}" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developer-admin-binding
  annotations:
    description: "INSECURE! Grants cluster-admin to developer"
    granted-by: "infrastructure-team"
    granted-date: "2025-10-15"
    reason: "Temporary for migration project"
    # TODO: REVOKE THIS ACCESS! (forgot to do it for 3 months!)
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin  # DANGEROUS! Full cluster control!
subjects:
- kind: User
  name: developer-user
  apiGroup: rbac.authorization.k8s.io
EOF
}

function create_sample_production_app() {
    cat > "${SAMPLE_APP_FILE}" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-api
  namespace: production
  labels:
    app: payment-api
    tier: backend
    criticality: high
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-api
  template:
    metadata:
      labels:
        app: payment-api
        tier: backend
    spec:
      containers:
      - name: api
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: payment-api
  namespace: production
  labels:
    app: payment-api
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    name: http
  selector:
    app: payment-api
EOF
}

function apply_resources() {
    echo ""
    echo "Creating namespaces..."
    kubectl apply -f "${NS_PROD_FILE}"
    kubectl apply -f "${NS_STAGE_FILE}"
    kubectl apply -f "${NS_DEV_FILE}"
    
    echo ""
    echo "Creating INSECURE ClusterRoleBinding (cluster-admin to developer)..."
    kubectl apply -f "${CLUSTER_ADMIN_BINDING_FILE}"
    
    echo ""
    echo "Deploying sample production application..."
    kubectl apply -f "${SAMPLE_APP_FILE}"
    
    echo ""
    echo "Waiting for deployment to be ready..."
    kubectl rollout status deployment/payment-api -n production --timeout=60s || true
}

function demonstrate_security_issue() {
    echo ""
    echo "=========================================="
    echo "DEMONSTRATING SECURITY VULNERABILITY"
    echo "=========================================="
    echo ""
    echo "Checking developer-user permissions..."
    echo ""
    
    echo "Can developer-user delete deployments in production?"
    kubectl auth can-i delete deployments --namespace=production --as=developer-user
    
    echo ""
    echo "Can developer-user delete namespaces?"
    kubectl auth can-i delete namespaces --as=developer-user
    
    echo ""
    echo "Can developer-user modify RBAC?"
    kubectl auth can-i create clusterrolebindings --as=developer-user
    
    echo ""
    echo "=========================================="
    echo "⚠️  CRITICAL SECURITY ISSUE CONFIRMED!"
    echo "=========================================="
    echo ""
    echo "Developer has cluster-admin privileges!"
    echo "One command can destroy production:"
    echo ""
    echo "  kubectl delete deployment payment-api -n production"
    echo ""
    echo "This would cause:"
    echo "  - Complete payment processing stopped"
    echo "  - All transactions halted"
    echo "  - Compliance violations"
    echo "  - Multi-million dollar impact"
    echo ""
}

function finalize_lab_setup() {
    chown -R user:user "${BASE_DIR}" 2>/dev/null || true

    echo ""
    echo "=========================================="
    echo "FINANCEFLOW RBAC SECURITY LAB"
    echo "=========================================="
    echo ""
    echo "Lab manifests created in: ${BASE_DIR}"
    echo ""
    echo "=========================================="
    echo "CURRENT INSECURE STATE:"
    echo "=========================================="
    echo ""
    echo "❌ Developer has cluster-admin (full cluster control)"
    echo "❌ Can delete any resource in any namespace"
    echo "❌ Can modify RBAC policies"
    echo "❌ No namespace restrictions"
    echo "❌ Production applications at risk"
    echo "❌ Violates principle of least privilege"
    echo ""
    echo "=========================================="
    echo "YOUR MISSION:"
    echo "=========================================="
    echo ""
    echo "1. CREATE DEVELOPER ROLE (development namespace)"
    echo "   - Full CRUD on pods, deployments, services"
    echo ""
    echo "2. CREATE PRODUCTION VIEWER ROLE"
    echo "   - Read-only access (get, list, watch)"
    echo ""
    echo "3. CREATE CI/CD SERVICEACCOUNT"
    echo "   - Deploy permissions only (no delete)"
    echo ""
    echo "4. REMOVE CLUSTER-ADMIN BINDING"
    echo "   - Delete: developer-admin-binding"
    echo ""
    echo "5. VERIFY ACCESS CONTROL"
    echo "   - Test with kubectl auth can-i commands"
    echo ""
    echo "=========================================="
}

function main() {
    create_base_directory
    create_namespace_yamls
    create_insecure_cluster_admin_binding
    create_sample_production_app
    apply_resources
    demonstrate_security_issue
    finalize_lab_setup
}

main