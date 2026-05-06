#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
BASE_DIR="/home/user/streamline-argocd-lab"


function test_rbac_frontend_role_staging() {
    local policy
    policy=$(kubectl get configmap argocd-rbac-cm -n argocd -o jsonpath='{.data.policy\.csv}' 2>/dev/null || true)

    if echo "${policy}" | grep -q "role:frontend-deployer" && \
       echo "${policy}" | grep "role:frontend-deployer" | grep -q "staging/\*"; then
        print_status "success" "Lab Passed: role:frontend-deployer policy correctly references project 'staging'."
    else
        print_status "failed" "Lab Failed: The role:frontend-deployer policy in 'argocd-rbac-cm' does not reference 'staging/*'. The frontend-app Application lives in the 'staging' project. If the role's policy lines target 'production/*' instead, john_doe has no effective permissions on any staging resource and cannot sync or manage frontend-app. Update all four policy lines for role:frontend-deployer to reference 'staging/*'."
        exit 1
    fi
}

function test_rbac_frontend_role_not_production() {
    local policy
    policy=$(kubectl get configmap argocd-rbac-cm -n argocd -o jsonpath='{.data.policy\.csv}' 2>/dev/null || true)

    if echo "${policy}" | grep "role:frontend-deployer" | grep -q "production/\*"; then
        print_status "failed" "Lab Failed: The role:frontend-deployer policy still references 'production/*'. This scopes the role to the production project where frontend-app does not exist, locking out the frontend-team entirely. Change all role:frontend-deployer policy lines from 'production/*' to 'staging/*'."
        exit 1
    else
        print_status "success" "Lab Passed: role:frontend-deployer policy does not reference project 'production'."
    fi
}

function test_api_server_selfheal_true() {
    local selfheal
    selfheal=$(kubectl get application api-server -n argocd -o jsonpath='{.spec.syncPolicy.automated.selfHeal}' 2>/dev/null || true)

    if [ "${selfheal}" = "true" ]; then
        print_status "success" "Lab Passed: api-server Application has selfHeal set to true."
    else
        print_status "failed" "Lab Failed: The api-server Application has selfHeal set to '${selfheal:-false}'. With selfHeal disabled, ArgoCD detects drift when a manual change is made directly to the cluster but never reconciles it back to the Git state. The application sits in OutOfSync indefinitely. Set syncPolicy.automated.selfHeal to true in api-server.yaml and reapply."
        exit 1
    fi
}

test_rbac_frontend_role_staging
test_rbac_frontend_role_not_production
test_api_server_selfheal_true
print_status "success" "Lab Passed: ArgoCD RBAC frontend-deployer role is correctly scoped to staging and api-server Application has selfHeal enabled."
exit 0
