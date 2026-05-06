#!/bin/bash
# setup-argocd-lab.sh
# Creates the broken StreamLine Technologies ArgoCD lab environment.
# Run as: sudo bash setup-argocd-lab.sh
#
# Environment:
#   - K3s single-node cluster
#   - ArgoCD installed in 'argocd' namespace
#   - Gitea running at http://localhost:3000
#   - ArgoCD admin credentials: admin / admin_password
#   - Gitea admin credentials:  judge / judge123

set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

HOME_DIR="/home/user"
BASE_DIR="/home/user/streamline-argocd-lab"
GITEA_URL="http://localhost:3000"
GITEA_ADMIN_USER="judge"
GITEA_ADMIN_PASS="judge123"
GITEA_REPO="streamline-manifests"
REPO_URL="${GITEA_URL}/${GITEA_ADMIN_USER}/${GITEA_REPO}"
ARGOCD_NAMESPACE="argocd"

mkdir -p "${BASE_DIR}"

function log() { echo "[setup] $*"; }


function wait_for_k3s() {
    log "Waiting for K3s API server..."
    local retries=30
    until kubectl cluster-info &>/dev/null || [ "${retries}" -eq 0 ]; do
        sleep 3
        retries=$((retries - 1))
    done
    if [ "${retries}" -eq 0 ]; then
        echo "ERROR: K3s API server not reachable." >&2; exit 1
    fi
    log "  K3s API server is ready"
}

function wait_for_argocd() {
    log "Waiting for ArgoCD server deployment..."
    kubectl rollout status deployment/argocd-server -n "${ARGOCD_NAMESPACE}" --timeout=120s
    log "  ArgoCD server is ready"
}

function argocd_login() {
    log "Logging in to ArgoCD CLI (core mode)..."
    argocd login --core --insecure 2>/dev/null || true
    kubectl config set-context --current --namespace="${ARGOCD_NAMESPACE}" &>/dev/null || true
    log "  ArgoCD CLI ready"
}

function setup_gitea_repo() {
    log "Creating Gitea repository '${GITEA_REPO}'..."

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${GITEA_URL}/api/v1/user/repos" \
        -H "Content-Type: application/json" \
        -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}" \
        -d "{\"name\":\"${GITEA_REPO}\",\"private\":false,\"auto_init\":true,\"default_branch\":\"main\"}")

    if [ "${http_code}" = "201" ]; then
        log "  Repository created"
    elif [ "${http_code}" = "409" ]; then
        log "  Repository already exists, skipping"
    else
        echo "ERROR: Gitea repo creation failed (HTTP ${http_code})" >&2; exit 1
    fi

    local repo_dir
    repo_dir=$(mktemp -d)
    git clone "http://${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}@localhost:3000/${GITEA_ADMIN_USER}/${GITEA_REPO}.git" \
        "${repo_dir}" 2>/dev/null

    mkdir -p "${repo_dir}/apps/frontend" "${repo_dir}/apps/api-server"

    cat > "${repo_dir}/apps/frontend/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: nginx:alpine
          ports:
            - containerPort: 80
EOF

    cat > "${repo_dir}/apps/api-server/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
        - name: api-server
          image: nginx:alpine
          ports:
            - containerPort: 8080
EOF

    cd "${repo_dir}"
    git config user.email "judge@example.com"
    git config user.name "judge"
    git add .
    git diff --cached --quiet || git commit -m "Add stub app manifests"
    git push origin main 2>/dev/null || true
    cd - >/dev/null
    rm -rf "${repo_dir}"
    log "  Manifests pushed to ${REPO_URL}"
}

# --------------------------------------------------
# Register Gitea repo with ArgoCD as a known repo secret
# --------------------------------------------------
function register_repo_with_argocd() {
    log "Registering Gitea repo with ArgoCD..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: streamline-gitea-repo
  namespace: ${ARGOCD_NAMESPACE}
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: ${REPO_URL}
  username: ${GITEA_ADMIN_USER}
  password: ${GITEA_ADMIN_PASS}
EOF
    log "  Repo secret registered"
}

# --------------------------------------------------
# Namespaces
# --------------------------------------------------
function ensure_namespaces() {
    log "Ensuring app namespaces exist..."
    kubectl create namespace frontend 2>/dev/null || log "  frontend already exists"
    kubectl create namespace backend  2>/dev/null || log "  backend already exists"
}

# --------------------------------------------------
# ArgoCD Projects
# --------------------------------------------------
function create_argocd_projects() {
    log "Creating ArgoCD projects..."

    kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: staging
  namespace: ${ARGOCD_NAMESPACE}
spec:
  description: Staging environment project
  sourceRepos:
    - "${REPO_URL}"
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
EOF

    kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: ${ARGOCD_NAMESPACE}
spec:
  description: Production environment project
  sourceRepos:
    - "${REPO_URL}"
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
EOF
    log "  Projects 'staging' and 'production' created"
}

# --------------------------------------------------
# ArgoCD RBAC ConfigMap (BROKEN)
#
# BUG 1 — role:frontend-deployer policy lines reference
#   proj:production/* instead of proj:staging/*. The
#   frontend-app Application lives in 'staging'. john_doe
#   is bound to this role, but the role grants no effective
#   permissions on any staging resource. All actions by
#   john_doe are silently denied.
#
#   Broken:   production/*
#   Correct:  staging/*
# --------------------------------------------------
function create_rbac_configmap() {
    log "Applying broken RBAC ConfigMap..."

    cat > "${BASE_DIR}/argocd-rbac-cm.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    # frontend-deployer — BROKEN: scoped to production instead of staging
    p, role:frontend-deployer, applications, get,    production/*, allow
    p, role:frontend-deployer, applications, sync,   production/*, allow
    p, role:frontend-deployer, applications, create, production/*, allow
    p, role:frontend-deployer, applications, update, production/*, allow

    # backend-deployer — correct
    p, role:backend-deployer, applications, get,    staging/*, allow
    p, role:backend-deployer, applications, sync,   staging/*, allow
    p, role:backend-deployer, applications, create, staging/*, allow
    p, role:backend-deployer, applications, update, staging/*, allow

    # User bindings
    g, john_doe, role:frontend-deployer
    g, admin,    role:backend-deployer
EOF

    kubectl apply -f "${BASE_DIR}/argocd-rbac-cm.yaml"
    log "  argocd-rbac-cm applied (john_doe → broken frontend-deployer)"
}

# --------------------------------------------------
# frontend-app Application (correct)
# --------------------------------------------------
function create_frontend_app() {
    log "Creating frontend-app Application..."

    cat > "${BASE_DIR}/frontend-app.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend-app
  namespace: ${ARGOCD_NAMESPACE}
spec:
  project: staging
  source:
    repoURL: ${REPO_URL}
    targetRevision: main
    path: apps/frontend
  destination:
    server: https://kubernetes.default.svc
    namespace: frontend
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

    kubectl apply -f "${BASE_DIR}/frontend-app.yaml"
    log "  frontend-app created"
}

# --------------------------------------------------
# api-server Application (BROKEN)
#
# BUG 2 — selfHeal: false. ArgoCD detects cluster drift
#   but never auto-reconciles. The app stays OutOfSync
#   indefinitely — Git is no longer the source of truth.
#
#   Broken:   selfHeal: false
#   Correct:  selfHeal: true
# --------------------------------------------------
function create_api_server_app() {
    log "Creating api-server Application (broken selfHeal)..."

    cat > "${BASE_DIR}/api-server.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api-server
  namespace: ${ARGOCD_NAMESPACE}
spec:
  project: staging
  source:
    repoURL: ${REPO_URL}
    targetRevision: main
    path: apps/api-server
  destination:
    server: https://kubernetes.default.svc
    namespace: backend
  syncPolicy:
    automated:
      prune: true
      selfHeal: false
EOF

    kubectl apply -f "${BASE_DIR}/api-server.yaml"
    log "  api-server created with selfHeal: false (broken)"
}

# --------------------------------------------------
# db-migrate PostSync Hook Job (BROKEN)
#
# BUG 3 — hook-delete-policy: HookFailed deletes the Job
#   only on failure. Successful runs accumulate in the
#   backend namespace. ArgoCD hits its resource comparison
#   limit → ComparisonError: too many resources → all
#   future syncs for api-server are blocked.
#
#   Broken:   HookFailed
#   Correct:  HookSucceeded
# --------------------------------------------------
function create_db_migrate_hook() {
    log "Creating db-migrate hook (broken deletion policy)..."

    cat > "${BASE_DIR}/db-migrate-hook.yaml" <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  namespace: backend
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookFailed
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: busybox:1.35
          command:
            - /bin/sh
            - -c
            - |
              echo "Running database migrations..."
              sleep 2
              echo "Migrations complete."
EOF

    kubectl apply -f "${BASE_DIR}/db-migrate-hook.yaml"
    log "  db-migrate created with HookFailed (broken)"
}

# --------------------------------------------------
# Important info file
# --------------------------------------------------
function create_imp_info_file() {
    cat > "${HOME_DIR}/imp_info.txt" <<EOF

============================================================
  STREAMLINE ARGOCD LAB — ENVIRONMENT READY
============================================================

  Cluster:    K3s  |  KUBECONFIG: /etc/rancher/k3s/k3s.yaml
  ArgoCD NS:  argocd
  Gitea:      ${REPO_URL}

  ArgoCD Applications:
    frontend-app   (project: staging, namespace: frontend)
    api-server     (project: staging, namespace: backend)

  Hook Job:
    db-migrate   (namespace: backend, phase: PostSync)

  Gitea users:
    judge / judge123            (admin)
    john_doe / johnpassword123  (standard user → role:frontend-deployer)

  ArgoCD credentials:  admin / admin_password

  There are 3 bugs. Find and fix them all.

  Useful commands:
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    kubectl get configmap argocd-rbac-cm -n argocd -o yaml
    kubectl get application api-server -n argocd -o yaml
    kubectl get job db-migrate -n backend -o yaml
    kubectl get applications -n argocd
    kubectl get jobs -n backend
============================================================
EOF
    log "  imp_info.txt written to ${HOME_DIR}"
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "Setting up StreamLine ArgoCD Lab..."
    echo ""

    echo "[1/9] Waiting for K3s..."
    wait_for_k3s

    echo "[2/9] Waiting for ArgoCD..."
    wait_for_argocd

    echo "[3/9] ArgoCD CLI login..."
    argocd_login

    echo "[4/9] Setting up Gitea repo and manifests..."
    setup_gitea_repo

    echo "[5/9] Registering repo with ArgoCD..."
    register_repo_with_argocd

    echo "[6/9] Ensuring namespaces exist..."
    ensure_namespaces

    echo "[7/9] Creating ArgoCD projects..."
    create_argocd_projects

    echo "[8/9] Applying broken RBAC ConfigMap..."
    create_rbac_configmap

    echo "[9/9] Creating Applications and hook Job..."
    create_frontend_app
    create_api_server_app
    create_db_migrate_hook
    create_imp_info_file

    echo ""
    echo "============================================================"
    echo "  STREAMLINE ARGOCD LAB — ENVIRONMENT READY"
    echo "============================================================"
    echo "  3 bugs planted. Good luck."
    echo "  Run: cat /home/user/imp_info.txt"
    echo "============================================================"
}

main

chown -R user:user "${BASE_DIR}" 2>/dev/null || true