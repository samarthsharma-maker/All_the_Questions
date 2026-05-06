#!/bin/bash
# solution.sh — Applies all three fixes to the NimbusFlow AI ArgoCD lab.
# Run as: bash solution.sh

set -euo pipefail

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

BASE_DIR="/home/user/nimbusflow-argocd-lab"
ARGOCD_NAMESPACE="argocd"
GITEA_URL="http://localhost:3000"
REPO_URL="${GITEA_URL}/judge/nimbusflow-manifests"

mkdir -p "${BASE_DIR}/fixed"

echo "============================================================"
echo "  NIMBUSFLOW AI ARGOCD LAB — APPLYING FIXES"
echo "============================================================"
echo ""

# --------------------------------------------------
# FIX 1: Correct sync window schedule from "* * * * *" to "0 9 * * 1-5"
#
# "* * * * *" activates the deny window at every minute —
# permanently blocking all automated syncs. "0 9 * * 1-5"
# activates it once per weekday at 09:00, running for 9h
# (until 18:00). Syncs outside business hours are allowed.
# --------------------------------------------------
echo "[Fix 1/3] Correcting sync window schedule on nimbusflow-prod AppProject..."

cat > "${BASE_DIR}/fixed/nimbusflow-prod-project.yaml" <<EOF
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
      schedule: "0 9 * * 1-5"
      duration: 9h
      applications:
        - '*'
      manualSync: false
EOF

kubectl apply -f "${BASE_DIR}/fixed/nimbusflow-prod-project.yaml"
cp "${BASE_DIR}/fixed/nimbusflow-prod-project.yaml" \
   "${BASE_DIR}/nimbusflow-prod-project.yaml"
echo "  Done: sync window schedule changed from '* * * * *' to '0 9 * * 1-5'"
echo ""

# --------------------------------------------------
# FIX 2: Replace syncOptions Replace=true with ServerSideApply=true
#
# Replace=true calls kubectl replace — it reconstructs the
# entire resource, deleting any field not in the Git manifest.
# ServerSideApply=true calls kubectl apply --server-side,
# updating only ArgoCD-owned fields and leaving fields managed
# by other controllers (HPA, cert-manager) untouched.
# --------------------------------------------------
echo "[Fix 2/3] Replacing Replace=true with ServerSideApply=true on inference-api..."

cat > "${BASE_DIR}/fixed/inference-api.yaml" <<EOF
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
      - ServerSideApply=true
EOF

kubectl apply -f "${BASE_DIR}/fixed/inference-api.yaml"
cp "${BASE_DIR}/fixed/inference-api.yaml" "${BASE_DIR}/inference-api.yaml"
echo "  Done: syncOptions changed from Replace=true to ServerSideApply=true"
echo ""

# --------------------------------------------------
# FIX 3: Correct the on-sync-failed trigger template reference
#
# The trigger referenced "app-sync-failed-notify" — a name
# with no matching template. The notifications controller
# silently dropped every sync failure alert. The correct
# name "app-sync-failed" matches the defined template.
# --------------------------------------------------
echo "[Fix 3/3] Correcting on-sync-failed trigger template name in argocd-notifications-cm..."

cat > "${BASE_DIR}/fixed/argocd-notifications-cm.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  trigger.on-sync-failed: |
    - when: app.status.operationState.phase in ['Error', 'Failed']
      send: [app-sync-failed]

  trigger.on-sync-succeeded: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-sync-succeeded]

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

kubectl apply -f "${BASE_DIR}/fixed/argocd-notifications-cm.yaml"
cp "${BASE_DIR}/fixed/argocd-notifications-cm.yaml" \
   "${BASE_DIR}/argocd-notifications-cm.yaml"
echo "  Done: on-sync-failed trigger now sends 'app-sync-failed'"
echo ""

echo "============================================================"
echo "  ALL FIXES APPLIED"
echo "============================================================"
echo ""
echo "  Fix 1: nimbusflow-prod AppProject sync window"
echo "         schedule: '* * * * *' → '0 9 * * 1-5'  (duration: 9h)"
echo ""
echo "  Fix 2: inference-api Application syncOptions"
echo "         Replace=true → ServerSideApply=true"
echo ""
echo "  Fix 3: argocd-notifications-cm trigger"
echo "         send: [app-sync-failed-notify] → send: [app-sync-failed]"
echo ""
echo "  Verify:"
echo "    kubectl get appproject nimbusflow-prod -n argocd -o yaml"
echo "    kubectl get application inference-api -n argocd -o yaml"
echo "    kubectl get configmap argocd-notifications-cm -n argocd -o yaml"
echo "============================================================"