#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
BASE_DIR="/home/user/streamline-argocd-lab"

function test_api_server_prune_retained() {
    local prune
    prune=$(kubectl get application api-server -n argocd -o jsonpath='{.spec.syncPolicy.automated.prune}' 2>/dev/null || true)

    if [ "${prune}" = "true" ]; then
        print_status "success" "Lab Passed: api-server Application retains prune: true."
    else
        print_status "failed" "Lab Failed: The api-server Application has prune set to '${prune:-false}'. Do not remove the prune setting when fixing selfHeal — both must be true for correct automated sync behaviour. Set syncPolicy.automated.prune to true in api-server.yaml and reapply."
        exit 1
    fi
}

function test_hook_delete_policy_succeeded() {
    local policy
    policy=$(kubectl get job db-migrate -n backend -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/hook-delete-policy}' 2>/dev/null || true)

    if [ "${policy}" = "HookSucceeded" ]; then
        print_status "success" "Lab Passed: db-migrate hook-delete-policy is correctly set to HookSucceeded."
    else
        print_status "failed" "Lab Failed: The db-migrate Job has hook-delete-policy set to '${policy:-MISSING}', expected 'HookSucceeded'. With HookFailed, completed migration Jobs are never deleted — they accumulate in the backend namespace. After several deployments ArgoCD hits its resource comparison limit and throws 'ComparisonError: too many resources', blocking all future syncs for api-server. Change the annotation to 'HookSucceeded' so successfully completed Jobs are cleaned up automatically."
        exit 1
    fi
}

function test_hook_delete_policy_not_failed() {
    local policy
    policy=$(kubectl get job db-migrate -n backend -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/hook-delete-policy}' 2>/dev/null || true)

    if [ "${policy}" = "HookFailed" ]; then
        print_status "failed" "Lab Failed: The db-migrate Job still has hook-delete-policy set to 'HookFailed'. This annotation deletes the Job only when it fails — meaning every successful migration run leaves a completed Job in the cluster. Replace 'HookFailed' with 'HookSucceeded' in db-migrate-hook.yaml and reapply."
        exit 1
    else
        print_status "success" "Lab Passed: db-migrate hook-delete-policy is no longer set to HookFailed."
    fi
}

test_api_server_prune_retained
test_hook_delete_policy_succeeded
test_hook_delete_policy_not_failed

print_status "success" "All Lab Tests Passed: ArgoCD RBAC project scope, api-server selfHeal policy, and db-migrate hook deletion policy are all correctly configured."
exit 0
