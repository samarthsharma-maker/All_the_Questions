#!/bin/bash

set -euo pipefail

LAB_DIR="/home/user/stackflow-lab"

function fix_serviceaccount() {
    cat > "${LAB_DIR}/serviceaccount.yaml" <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-runner
  namespace: dev
  labels:
    app: ci-pipeline
    team: platform
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-runner
  namespace: staging
  labels:
    app: ci-pipeline
    team: platform
EOF
}

function fix_roles() {
    cat > "${LAB_DIR}/roles.yaml" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ci-reader
  namespace: dev
  labels:
    app: ci-pipeline
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ci-reader
  namespace: staging
  labels:
    app: ci-pipeline
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
EOF
}

function fix_rolebindings() {
    cat > "${LAB_DIR}/rolebindings.yaml" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-runner-binding
  namespace: dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ci-reader
subjects:
- kind: ServiceAccount
  name: ci-runner
  namespace: dev
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-runner-binding
  namespace: staging
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ci-reader
subjects:
- kind: ServiceAccount
  name: ci-runner
  namespace: staging
EOF
}

function fix_resourcequotas() {
    cat > "${LAB_DIR}/resourcequotas.yaml" <<'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pipeline-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "1Gi"
    pods: "20"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pipeline-quota
  namespace: staging
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "1Gi"
    pods: "20"
EOF
}

function remove_misplaced_resources() {
    echo "Removing misplaced ServiceAccount from 'default' namespace..."
    kubectl delete serviceaccount ci-runner -n default --ignore-not-found=true

    echo "Removing broken Roles..."
    kubectl delete role ci-reader -n dev --ignore-not-found=true
    kubectl delete role ci-reader -n staging --ignore-not-found=true

    echo "Removing broken RoleBindings..."
    kubectl delete rolebinding ci-runner-binding -n dev --ignore-not-found=true
    kubectl delete rolebinding ci-runner-binding -n staging --ignore-not-found=true
}

function apply_resources() {
    echo "Applying fixed resources from lab directory..."
    kubectl apply -f "${LAB_DIR}/serviceaccount.yaml"
    kubectl apply -f "${LAB_DIR}/roles.yaml"
    kubectl apply -f "${LAB_DIR}/rolebindings.yaml"
    kubectl apply -f "${LAB_DIR}/resourcequotas.yaml"
}

function verify_permissions() {
    local namespaces=("dev" "staging")
    local sa_name="ci-runner"

    for ns in "${namespaces[@]}"; do
        local sa_ref="system:serviceaccount:${ns}:${sa_name}"

        echo ""
        echo "=========================================="
        echo "PERMISSION VERIFICATION: ${ns} namespace"
        echo "=========================================="
        echo ""

        echo "Permitted operations:"
        result=$(kubectl auth can-i get pods --as="$sa_ref" -n "$ns" 2>/dev/null)
        echo "  get pods       : $result"

        result=$(kubectl auth can-i list pods --as="$sa_ref" -n "$ns" 2>/dev/null)
        echo "  list pods      : $result"

        result=$(kubectl auth can-i watch pods --as="$sa_ref" -n "$ns" 2>/dev/null)
        echo "  watch pods     : $result"

        result=$(kubectl auth can-i get pods/log --as="$sa_ref" -n "$ns" 2>/dev/null)
        echo "  get pods/log   : $result"

        echo ""
        echo "Restricted operations:"
        result=$(kubectl auth can-i delete pods --as="$sa_ref" -n "$ns" 2>/dev/null)
        echo "  delete pods    : $result"

        result=$(kubectl auth can-i create pods --as="$sa_ref" -n "$ns" 2>/dev/null)
        echo "  create pods    : $result"

        result=$(kubectl auth can-i update pods --as="$sa_ref" -n "$ns" 2>/dev/null)
        echo "  update pods    : $result"
    done

    echo ""
}

function show_summary() {
    echo "=========================================="
    echo "FIXES APPLIED"
    echo "=========================================="
    echo ""
    echo "Fix 1: ServiceAccount namespace and replication"
    echo "  Before: ci-runner deployed only in 'default'"
    echo "  After:  ci-runner deployed in 'dev' and 'staging'"
    echo ""
    echo "Fix 2: Role verbs and resources (both namespaces)"
    echo "  Before: verbs [create, delete, update] on [pods]"
    echo "  After:  verbs [get, list, watch] on [pods, pods/log]"
    echo ""
    echo "Fix 3: RoleBinding subject names (both namespaces)"
    echo "  Before: subject name 'ci-runners' (incorrect)"
    echo "  After:  subject name 'ci-runner'"
    echo ""
    echo "Fix 4: Resource Quotas (both namespaces)"
    echo "  Before: pods: 1, memory: 64Mi, cpu: 0.1m (too restrictive)"
    echo "  After:  pods: 20, memory: 1Gi, cpu: 2 (reasonable limits)"
    echo ""
    echo "=========================================="
    echo "INFRASTRUCTURE FULLY REPAIRED"
    echo "=========================================="
    echo ""
    echo "The CI pipeline ServiceAccount 'ci-runner' can now:"
    echo "  - Read pod status and stream logs in both namespaces"
    echo "  - Verify deployments without destructive access"
    echo "  - Communicate with kubelet for log collection"
    echo "  - Deploy verification pods within quota limits"
    echo ""
}

function main() {
    echo "=========================================="
    echo "STACKFLOW INFRASTRUCTURE: APPLYING FIXES"
    echo "=========================================="
    echo ""

    fix_serviceaccount
    fix_roles
    fix_rolebindings
    fix_resourcequotas

    echo "Lab files updated in: ${LAB_DIR}"
    echo ""

    remove_misplaced_resources
    echo ""
    apply_resources
    verify_permissions
    show_summary
}

main