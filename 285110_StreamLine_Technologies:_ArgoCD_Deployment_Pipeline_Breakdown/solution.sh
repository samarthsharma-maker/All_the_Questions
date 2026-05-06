#!/bin/bash
# solution.sh — Applies all three fixes to the StreamLine ArgoCD lab.
# Run as: bash solution.sh

set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

BASE_DIR="/home/user/streamline-argocd-lab"
ARGOCD_NAMESPACE="argocd"
GITEA_URL="http://localhost:3000"
REPO_URL="${GITEA_URL}/judge/streamline-manifests"

mkdir -p "${BASE_DIR}/fixed"

echo "============================================================"
echo "  STREAMLINE ARGOCD LAB — APPLYING FIXES"
echo "============================================================"
echo ""

# --------------------------------------------------
# FIX 1: Change frontend-deployer role scope from production → staging
#
# john_doe is bound to role:frontend-deployer. The role's
# policy lines all targeted production/* — a project where
# john_doe has no Applications. Every action was silently
# denied. Changing to staging/* gives john_doe the intended
# permissions on frontend-app.
# --------------------------------------------------
echo "[Fix 1/3] Correcting frontend-deployer role scope to 'staging'..."

cat > "${BASE_DIR}/fixed/argocd-rbac-cm.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    # frontend-deployer — correctly scoped to staging
    p, role:frontend-deployer, applications, get,    staging/*, allow
    p, role:frontend-deployer, applications, sync,   staging/*, allow
    p, role:frontend-deployer, applications, create, staging/*, allow
    p, role:frontend-deployer, applications, update, staging/*, allow

    # backend-deployer — correctly scoped to staging
    p, role:backend-deployer, applications, get,    staging/*, allow
    p, role:backend-deployer, applications, sync,   staging/*, allow
    p, role:backend-deployer, applications, create, staging/*, allow
    p, role:backend-deployer, applications, update, staging/*, allow

    # User bindings
    g, john_doe, role:frontend-deployer
    g, admin,    role:backend-deployer
EOF

kubectl apply -f "${BASE_DIR}/fixed/argocd-rbac-cm.yaml"
echo "  Done: role:frontend-deployer scope changed from production/* to staging/*"
echo ""

# --------------------------------------------------
# FIX 2: Enable selfHeal on api-server Application
#
# With selfHeal: false ArgoCD reports drift but never
# corrects it. Any direct kubectl patch or edit persists
# indefinitely. selfHeal: true restores GitOps compliance —
# ArgoCD automatically reconciles drift back to Git state.
# --------------------------------------------------
echo "[Fix 2/3] Enabling selfHeal on api-server Application..."

cat > "${BASE_DIR}/fixed/api-server.yaml" <<EOF
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
      selfHeal: true
EOF

kubectl apply -f "${BASE_DIR}/fixed/api-server.yaml"
cp "${BASE_DIR}/fixed/api-server.yaml" "${BASE_DIR}/api-server.yaml"
echo "  Done: selfHeal changed from false to true on api-server"
echo ""

# --------------------------------------------------
# FIX 3: Change db-migrate hook-delete-policy to HookSucceeded
#
# HookFailed left completed Jobs in place after success.
# Over time they accumulated in the backend namespace until
# ArgoCD's comparison limit was hit. HookSucceeded cleans up
# after a successful run, preventing accumulation.
# Failed Jobs are intentionally left for debugging.
# --------------------------------------------------
echo "[Fix 3/3] Correcting db-migrate hook-delete-policy to HookSucceeded..."

cat > "${BASE_DIR}/fixed/db-migrate-hook.yaml" <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  namespace: backend
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
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

kubectl apply -f "${BASE_DIR}/fixed/db-migrate-hook.yaml"
cp "${BASE_DIR}/fixed/db-migrate-hook.yaml" "${BASE_DIR}/db-migrate-hook.yaml"
echo "  Done: hook-delete-policy changed from HookFailed to HookSucceeded"
echo ""

echo "============================================================"
echo "  ALL FIXES APPLIED"
echo "============================================================"
echo ""
echo "  Fix 1: argocd-rbac-cm — role:frontend-deployer"
echo "         production/* → staging/*"
echo ""
echo "  Fix 2: api-server Application sync policy"
echo "         selfHeal: false → true"
echo ""
echo "  Fix 3: db-migrate PostSync hook"
echo "         HookFailed → HookSucceeded"
echo ""
echo "  Verify:"
echo "    kubectl get configmap argocd-rbac-cm -n argocd -o yaml"
echo "    kubectl get application api-server -n argocd -o yaml"
echo "    kubectl get job db-migrate -n backend -o yaml"
echo "============================================================"