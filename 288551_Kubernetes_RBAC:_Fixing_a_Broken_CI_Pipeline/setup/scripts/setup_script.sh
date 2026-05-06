#!/bin/bash

set -euo pipefail

BASE_DIR="/home/user/stackflow-lab"

mkdir -p "${BASE_DIR}"

function create_namespaces() {
    cat > "${BASE_DIR}/namespaces.yaml" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: dev
  labels:
    environment: development
    team: platform-engineering
---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
    team: platform-engineering
EOF
}

function create_broken_serviceaccount() {
    cat > "${BASE_DIR}/serviceaccount.yaml" <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ci-runner
  namespace: default
  labels:
    app: ci-pipeline
    team: platform
EOF
}

function create_broken_roles() {
    cat > "${BASE_DIR}/roles.yaml" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ci-reader
  namespace: dev
  labels:
    app: ci-pipeline
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["create", "delete", "update"]
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
  resources: ["pods"]
  verbs: ["create", "delete", "update"]
EOF
}

function create_broken_rolebindings() {
    cat > "${BASE_DIR}/rolebindings.yaml" <<'EOF'
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
  name: ci-runners
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
  name: ci-runners
  namespace: staging
EOF
}

function create_broken_resourcequotas() {
    cat > "${BASE_DIR}/resourcequotas.yaml" <<'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pipeline-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "0.1"
    requests.memory: "64Mi"
    pods: "1"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pipeline-quota
  namespace: staging
spec:
  hard:
    requests.cpu: "0.1"
    requests.memory: "64Mi"
    pods: "1"
EOF
}

function apply_resources() {
    kubectl apply -f "${BASE_DIR}/namespaces.yaml"
    kubectl apply -f "${BASE_DIR}/serviceaccount.yaml"
    kubectl apply -f "${BASE_DIR}/roles.yaml"
    kubectl apply -f "${BASE_DIR}/rolebindings.yaml"
    kubectl apply -f "${BASE_DIR}/resourcequotas.yaml"
}

function finalize() {
    chown -R user:user "${BASE_DIR}" 2>/dev/null || true

    echo
    echo "=========================================="
    echo "STACKFLOW RBAC LAB: ENVIRONMENT READY"
    echo "=========================================="
    echo
    echo "Lab files created in: ${BASE_DIR}"
    echo
    echo "Broken RBAC and Resource Quotas"
    echo "have been deployed across dev and staging namespaces."
    echo
    echo "Namespaces: dev, staging"
    echo
    echo "Your task:"
    echo "  Investigate configurations across dev and staging"
    echo "  namespaces. Find and fix misconfigurations in:"
    echo "  - RBAC (ServiceAccounts, Roles, RoleBindings)"
    echo "  - Resource Quotas (too restrictive limits)"
    echo
    echo "Start by inspecting existing resources:"
    echo "  kubectl get serviceaccounts -n dev"
    echo "  kubectl get serviceaccounts -n staging"
    echo "  kubectl get roles -n dev -n staging"
    echo "  kubectl get rolebindings -n dev -n staging"
    echo "  kubectl get resourcequotas -n dev -n staging"
    echo
    echo "=========================================="
}

function main() {
    create_namespaces
    create_broken_serviceaccount
    create_broken_roles
    create_broken_rolebindings
    create_broken_resourcequotas
    apply_resources
    finalize
}

main