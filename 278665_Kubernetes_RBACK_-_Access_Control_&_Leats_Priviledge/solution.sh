#!/bin/bash

set -euo pipefail

BASE_DIR="$HOME/financeflow-solution"
NAMESPACE_PROD="production"
NAMESPACE_DEV="development"

mkdir -p "$BASE_DIR"

# --------------------------------------------------
# Developer Role (Development Namespace)
# --------------------------------------------------
function create_developer_role() {
    cat > "$BASE_DIR/developer-role.yaml" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: development
rules:
# Full control of common resources in development namespace
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

# Allow reading logs for debugging
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]

# Allow port-forwarding for debugging
- apiGroups: [""]
  resources: ["pods/portforward"]
  verbs: ["create"]

# Allow exec into pods for debugging
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
EOF
}

# --------------------------------------------------
# Developer RoleBinding (Development Namespace)
# --------------------------------------------------
function create_developer_rolebinding() {
    cat > "$BASE_DIR/developer-rolebinding.yaml" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: development
subjects:
- kind: User
  name: developer-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
EOF
}

# --------------------------------------------------
# Production Viewer Role (Read-Only)
# --------------------------------------------------
function create_prod_viewer_role() {
    cat > "$BASE_DIR/prod-viewer-role.yaml" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: prod-viewer
  namespace: production
rules:
# Read-only access to view production resources
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "events", "endpoints"]
  verbs: ["get", "list", "watch"]

- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch"]

- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch"]

# Can view logs for troubleshooting
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]

# NO create, update, patch, delete permissions!
# Read-only access only
EOF
}

# --------------------------------------------------
# Production Viewer RoleBinding
# --------------------------------------------------
function create_prod_viewer_rolebinding() {
    cat > "$BASE_DIR/prod-viewer-rolebinding.yaml" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: prod-viewer-binding
  namespace: production
subjects:
- kind: User
  name: developer-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: prod-viewer
  apiGroup: rbac.authorization.k8s.io
EOF
}

# --------------------------------------------------
# CI/CD ServiceAccount
# --------------------------------------------------
function create_cicd_serviceaccount() {
    cat > "$BASE_DIR/cicd-serviceaccount.yaml" <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cicd-deployer
  namespace: production
EOF
}

# --------------------------------------------------
# CI/CD Deployer Role (Deploy-Only, No Delete)
# --------------------------------------------------
function create_cicd_deployer_role() {
    cat > "$BASE_DIR/cicd-deployer-role.yaml" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cicd-deployer-role
  namespace: production
rules:
# Can deploy and update applications
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "create", "update", "patch"]

# Can manage ReplicaSets (created by Deployments)
- apiGroups: ["apps"]
  resources: ["replicasets"]
  verbs: ["get", "list"]

# Can manage Services
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list", "create", "update", "patch"]

# Can manage ConfigMaps for application config
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "create", "update", "patch"]

# Can read pods to verify deployments
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]

# Can read pod logs
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]

# CRITICAL: NO DELETE PERMISSIONS!
# This prevents accidental removal of resources
# Must manually delete if needed (with approval)
EOF
}

# --------------------------------------------------
# CI/CD Deployer RoleBinding
# --------------------------------------------------
function create_cicd_deployer_rolebinding() {
    cat > "$BASE_DIR/cicd-deployer-rolebinding.yaml" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cicd-deployer-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: cicd-deployer
  namespace: production
roleRef:
  kind: Role
  name: cicd-deployer-role
  apiGroup: rbac.authorization.k8s.io
EOF
}

# --------------------------------------------------
# Ensure Namespaces Exist
# --------------------------------------------------
function ensure_namespaces() {
    for ns in production staging development; do
        if ! kubectl get namespace "$ns" &>/dev/null; then
            echo "Creating namespace $ns..."
            kubectl create namespace "$ns"
        else
            echo "Namespace $ns already exists."
        fi
    done
}

# --------------------------------------------------
# Apply All RBAC Resources
# --------------------------------------------------
function apply_rbac_resources() {
    echo ""
    echo "Applying developer Role and RoleBinding (development namespace)..."
    kubectl apply -f "$BASE_DIR/developer-role.yaml"
    kubectl apply -f "$BASE_DIR/developer-rolebinding.yaml"
    
    echo ""
    echo "Applying production viewer Role and RoleBinding..."
    kubectl apply -f "$BASE_DIR/prod-viewer-role.yaml"
    kubectl apply -f "$BASE_DIR/prod-viewer-rolebinding.yaml"
    
    echo ""
    echo "Creating CI/CD ServiceAccount and deployer Role..."
    kubectl apply -f "$BASE_DIR/cicd-serviceaccount.yaml"
    kubectl apply -f "$BASE_DIR/cicd-deployer-role.yaml"
    kubectl apply -f "$BASE_DIR/cicd-deployer-rolebinding.yaml"
}

# --------------------------------------------------
# Remove Insecure Cluster-Admin Binding
# --------------------------------------------------
function remove_cluster_admin_binding() {
    echo ""
    echo "=========================================="
    echo "REMOVING INSECURE CLUSTER-ADMIN BINDING"
    echo "=========================================="
    echo ""
    
    if kubectl get clusterrolebinding developer-admin-binding &>/dev/null; then
        echo "Deleting developer-admin-binding ClusterRoleBinding..."
        kubectl delete clusterrolebinding developer-admin-binding
        echo "✓ Cluster-admin binding removed!"
    else
        echo "developer-admin-binding not found (already removed or doesn't exist)"
    fi
}

# --------------------------------------------------
# Verify RBAC Configuration
# --------------------------------------------------
function verify_rbac() {
    echo ""
    echo "=========================================="
    echo "VERIFYING RBAC CONFIGURATION"
    echo "=========================================="
    echo ""
    
    echo "Test 1: Developer CAN create pods in development"
    RESULT=$(kubectl auth can-i create pods --namespace=development --as=developer-user)
    echo "  Result: $RESULT"
    if [ "$RESULT" == "yes" ]; then
        echo "  ✓ PASS"
    else
        echo "  ✗ FAIL"
    fi
    
    echo ""
    echo "Test 2: Developer CANNOT delete deployments in production"
    RESULT=$(kubectl auth can-i delete deployments --namespace=production --as=developer-user)
    echo "  Result: $RESULT"
    if [ "$RESULT" == "no" ]; then
        echo "  ✓ PASS"
    else
        echo "  ✗ FAIL"
    fi
    
    echo ""
    echo "Test 3: Developer CAN view pods in production"
    RESULT=$(kubectl auth can-i get pods --namespace=production --as=developer-user)
    echo "  Result: $RESULT"
    if [ "$RESULT" == "yes" ]; then
        echo "  ✓ PASS"
    else
        echo "  ✗ FAIL"
    fi
    
    echo ""
    echo "Test 4: Developer CANNOT delete namespaces"
    RESULT=$(kubectl auth can-i delete namespaces --as=developer-user)
    echo "  Result: $RESULT"
    if [ "$RESULT" == "no" ]; then
        echo "  ✓ PASS"
    else
        echo "  ✗ FAIL"
    fi
    
    echo ""
    echo "Test 5: CI/CD ServiceAccount CAN deploy"
    RESULT=$(kubectl auth can-i create deployments --namespace=production --as=system:serviceaccount:production:cicd-deployer)
    echo "  Result: $RESULT"
    if [ "$RESULT" == "yes" ]; then
        echo "  ✓ PASS"
    else
        echo "  ✗ FAIL"
    fi
    
    echo ""
    echo "Test 6: CI/CD ServiceAccount CANNOT delete deployments"
    RESULT=$(kubectl auth can-i delete deployments --namespace=production --as=system:serviceaccount:production:cicd-deployer)
    echo "  Result: $RESULT"
    if [ "$RESULT" == "no" ]; then
        echo "  ✓ PASS"
    else
        echo "  ✗ FAIL"
    fi
    
    echo ""
    echo "Test 7: CI/CD ServiceAccount CANNOT delete StatefulSets"
    RESULT=$(kubectl auth can-i delete statefulsets --namespace=production --as=system:serviceaccount:production:cicd-deployer)
    echo "  Result: $RESULT"
    if [ "$RESULT" == "no" ]; then
        echo "  ✓ PASS"
    else
        echo "  ✗ FAIL"
    fi
}

# --------------------------------------------------
# Show Summary
# --------------------------------------------------
function show_summary() {
    echo ""
    echo "=========================================="
    echo "RBAC SECURITY FIXES COMPLETE"
    echo "=========================================="
    echo ""
    echo "Before (INSECURE):"
    echo "  ✗ Developer had cluster-admin"
    echo "  ✗ Could delete anything in any namespace"
    echo "  ✗ Could modify RBAC policies"
    echo "  ✗ No namespace restrictions"
    echo "  ✗ Single point of catastrophic failure"
    echo ""
    echo "After (SECURE):"
    echo "  ✓ Developer has namespace-scoped roles only"
    echo "  ✓ Full access in development namespace"
    echo "  ✓ Read-only access in production"
    echo "  ✓ Cannot delete production resources"
    echo "  ✓ Cannot modify cluster-level RBAC"
    echo "  ✓ CI/CD can deploy but not delete"
    echo "  ✓ Principle of least privilege enforced"
    echo ""
    echo "Roles Created:"
    echo "  1. developer-role (development namespace)"
    echo "     - Full CRUD on pods, deployments, services, etc."
    echo ""
    echo "  2. prod-viewer (production namespace)"
    echo "     - Read-only access (get, list, watch)"
    echo ""
    echo "  3. cicd-deployer-role (production namespace)"
    echo "     - Deploy and update only (no delete)"
    echo ""
    echo "Security Improvements:"
    echo "  ✓ Namespace isolation"
    echo "  ✓ No cluster-admin for developers"
    echo "  ✓ Read-only production access"
    echo "  ✓ Protected against accidental deletion"
    echo "  ✓ Compliance with PCI-DSS Requirement 7"
    echo "  ✓ Compliance with SOC 2 CC6.1"
    echo ""
    echo "Files created in: $BASE_DIR"
    echo ""
    echo "=========================================="
    echo "INCIDENT PREVENTED"
    echo "=========================================="
    echo "The FinanceFlow disaster cannot happen again!"
    echo "=========================================="
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "=========================================="
    echo "IMPLEMENTING SECURE RBAC"
    echo "=========================================="
    echo ""
    echo "Creating solution files in: $BASE_DIR"
    echo ""
    
    create_developer_role
    create_developer_rolebinding
    create_prod_viewer_role
    create_prod_viewer_rolebinding
    create_cicd_serviceaccount
    create_cicd_deployer_role
    create_cicd_deployer_rolebinding
    
    echo "Solution files created:"
    ls -1 "$BASE_DIR"
    echo ""
    
    ensure_namespaces
    apply_rbac_resources
    remove_cluster_admin_binding
    verify_rbac
    show_summary
}

main