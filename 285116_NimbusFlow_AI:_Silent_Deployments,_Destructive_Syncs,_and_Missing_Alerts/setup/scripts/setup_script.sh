#!/bin/bash
# setup-nimbusflow-argocd-lab.sh
# Creates the broken NimbusFlow AI ArgoCD lab environment.
# Run as: sudo bash setup-nimbusflow-argocd-lab.sh
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
BASE_DIR="/home/user/nimbusflow-argocd-lab"
GITEA_URL="http://localhost:3000"
GITEA_ADMIN_USER="judge"
GITEA_ADMIN_PASS="judge123"
GITEA_REPO="nimbusflow-manifests"
REPO_URL="${GITEA_URL}/${GITEA_ADMIN_USER}/${GITEA_REPO}"
ARGOCD_NAMESPACE="argocd"

mkdir -p "${BASE_DIR}"

function log() { echo "[setup] $*"; }

# --------------------------------------------------
# Wait for K3s API server
# --------------------------------------------------
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

# --------------------------------------------------
# Wait for ArgoCD server
# --------------------------------------------------
function wait_for_argocd() {
    log "Waiting for ArgoCD server deployment..."
    kubectl rollout status deployment/argocd-server \
        -n "${ARGOCD_NAMESPACE}" --timeout=120s
    log "  ArgoCD server is ready"
}

# --------------------------------------------------
# ArgoCD CLI login (core mode — no port-forward needed)
# --------------------------------------------------
function argocd_login() {
    log "Logging in to ArgoCD CLI (core mode)..."
    argocd login --core --insecure 2>/dev/null || true
    kubectl config set-context --current --namespace="${ARGOCD_NAMESPACE}" &>/dev/null || true
    log "  ArgoCD CLI ready"
}

# --------------------------------------------------
# Create Gitea repository and push stub manifests
# --------------------------------------------------
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

    mkdir -p "${repo_dir}/apps/inference-api"

    cat > "${repo_dir}/apps/inference-api/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inference-api
  namespace: inference
spec:
  replicas: 3
  selector:
    matchLabels:
      app: inference-api
  template:
    metadata:
      labels:
        app: inference-api
    spec:
      containers:
        - name: inference-api
          image: nimbusflow/inference-api:1.4.2
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
EOF

    cd "${repo_dir}"
    git config user.email "judge@example.com"
    git config user.name "judge"
    git add .
    git diff --cached --quiet || git commit -m "Add inference-api manifests"
    git push origin main 2>/dev/null || true
    cd - >/dev/null
    rm -rf "${repo_dir}"
    log "  Manifests pushed to ${REPO_URL}"
}

# --------------------------------------------------
# Register Gitea repo with ArgoCD
# --------------------------------------------------
function register_repo_with_argocd() {
    log "Registering Gitea repo with ArgoCD..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: nimbusflow-gitea-repo
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
# Namespace
# --------------------------------------------------
function ensure_namespaces() {
    log "Ensuring inference namespace exists..."
    kubectl create namespace inference 2>/dev/null || log "  inference already exists"
}

# --------------------------------------------------
# AppProject (BROKEN)
#
# BUG 1 — Sync window schedule is "* * * * *" instead of
#   "0 9 * * 1-5". A deny window with "* * * * *" is active
#   at every minute of every day — it permanently blocks
#   all automated syncs for any application in this project.
#   No Git push will ever trigger a deployment.
#
#   Broken:   schedule: "* * * * *"
#   Correct:  schedule: "0 9 * * 1-5"  duration: 9h
# --------------------------------------------------
function create_argocd_project() {
    log "Creating nimbusflow-prod AppProject (broken sync window)..."

    cat > "${BASE_DIR}/nimbusflow-prod-project.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: nimbusflow-prod
  namespace: ${ARGOCD_NAMESPACE}
spec:
  description: NimbusFlow production inference project
  sourceRepos:
    - "${REPO_URL}"
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
  syncWindows:
    - kind: deny
      schedule: "* * * * *"
      duration: 1h
      applications:
        - '*'
      manualSync: false
EOF
    # schedule: "* * * * *" is intentionally wrong.
    # Correct: "0 9 * * 1-5" with duration: 9h

    kubectl apply -f "${BASE_DIR}/nimbusflow-prod-project.yaml"
    log "  nimbusflow-prod project created with broken sync window"
}

# --------------------------------------------------
# inference-api Application (BROKEN)
#
# BUG 2 — syncOptions contains "Replace=true" instead of
#   "ServerSideApply=true". Replace causes ArgoCD to call
#   kubectl replace, which reconstructs the entire resource
#   from the Git manifest. Fields not present in Git —
#   such as those written by the HPA controller or injected
#   by admission webhooks — are silently deleted on every sync.
#
#   Broken:   syncOptions: ["Replace=true"]
#   Correct:  syncOptions: ["ServerSideApply=true"]
# --------------------------------------------------
function create_inference_api_app() {
    log "Creating inference-api Application (broken syncOptions)..."

    cat > "${BASE_DIR}/inference-api.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: inference-api
  namespace: ${ARGOCD_NAMESPACE}
  annotations:
    argocd-image-updater.argoproj.io/image-list: inference=nimbusflow/inference-api
    argocd-image-updater.argoproj.io/inference.update-strategy: semver
spec:
  project: nimbusflow-prod
  source:
    repoURL: ${REPO_URL}
    targetRevision: main
    path: apps/inference-api
  destination:
    server: https://kubernetes.default.svc
    namespace: inference
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - Replace=true
EOF
    # Replace=true is intentionally wrong. Correct: ServerSideApply=true

    kubectl apply -f "${BASE_DIR}/inference-api.yaml"
    log "  inference-api created with Replace=true (broken)"
}

# --------------------------------------------------
# ArgoCD Notifications ConfigMap (BROKEN)
#
# BUG 3 — The trigger "on-sync-failed" sends template
#   "app-sync-failed-notify" but the only defined template
#   is "app-sync-failed". The name mismatch causes the
#   notifications controller to silently drop every sync
#   failure alert — no message is ever sent to Slack.
#
#   Broken:   send: [app-sync-failed-notify]
#   Correct:  send: [app-sync-failed]
# --------------------------------------------------
function create_notifications_configmap() {
    log "Creating argocd-notifications-cm (broken trigger template name)..."

    cat > "${BASE_DIR}/argocd-notifications-cm.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  # Trigger: fires when a sync operation ends in Error or Failed state.
  # BROKEN: references template "app-sync-failed-notify" which does not exist.
  # Correct: send: [app-sync-failed]
  trigger.on-sync-failed: |
    - when: app.status.operationState.phase in ['Error', 'Failed']
      send: [app-sync-failed-notify]

  trigger.on-sync-succeeded: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-sync-succeeded]

  # Template: the actual notification message.
  # Named "app-sync-failed" — note: trigger above references the WRONG name.
  template.app-sync-failed: |
    message: |
      :red_circle: *{{.app.metadata.name}}* sync FAILED
      Reason: {{.app.status.operationState.message}}
      Project: {{.app.spec.project}}

  template.app-sync-succeeded: |
    message: |
      :large_green_circle: *{{.app.metadata.name}}* sync succeeded
      Revision: {{.app.status.operationState.syncResult.revision}}
EOF

    kubectl apply -f "${BASE_DIR}/argocd-notifications-cm.yaml"
    log "  argocd-notifications-cm applied (trigger references wrong template name)"
}

# --------------------------------------------------
# Important info file
# --------------------------------------------------
function create_imp_info_file() {
    cat > "${HOME_DIR}/imp_info.txt" <<EOF

============================================================
  NIMBUSFLOW AI ARGOCD LAB — ENVIRONMENT READY
============================================================

  Cluster:    K3s  |  KUBECONFIG: /etc/rancher/k3s/k3s.yaml
  ArgoCD NS:  argocd
  Gitea:      ${REPO_URL}

  ArgoCD Project:
    nimbusflow-prod  (has a deny sync window)

  ArgoCD Application:
    inference-api  (project: nimbusflow-prod, namespace: inference)

  Notifications ConfigMap:
    argocd-notifications-cm  (in argocd namespace)

  Gitea users:
    judge / judge123            (admin)
    john_doe / johnpassword123  (standard user)

  ArgoCD credentials:  admin / admin_password

  There are 3 bugs. Find and fix them all.

  Useful commands:
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    kubectl get appproject nimbusflow-prod -n argocd -o yaml
    kubectl get application inference-api -n argocd -o yaml
    kubectl get configmap argocd-notifications-cm -n argocd -o yaml
============================================================
EOF
    log "  imp_info.txt written"
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "Setting up NimbusFlow AI ArgoCD Lab..."
    echo ""

    echo "[1/8] Waiting for K3s..."
    wait_for_k3s

    echo "[2/8] Waiting for ArgoCD..."
    wait_for_argocd

    echo "[3/8] ArgoCD CLI login..."
    argocd_login

    echo "[4/8] Setting up Gitea repo and manifests..."
    setup_gitea_repo

    echo "[5/8] Registering repo with ArgoCD..."
    register_repo_with_argocd

    echo "[6/8] Ensuring namespaces exist..."
    ensure_namespaces

    echo "[7/8] Creating AppProject with broken sync window..."
    create_argocd_project

    echo "[8/8] Creating Application, broken syncOptions, and notifications..."
    create_inference_api_app
    create_notifications_configmap
    create_imp_info_file

    echo ""
    echo "============================================================"
    echo "  NIMBUSFLOW AI ARGOCD LAB — ENVIRONMENT READY"
    echo "============================================================"
    echo "  3 bugs planted. Good luck."
    echo "  Run: cat /home/user/imp_info.txt"
    echo "============================================================"
}

main

chown -R user:user "${BASE_DIR}" 2>/dev/null || true