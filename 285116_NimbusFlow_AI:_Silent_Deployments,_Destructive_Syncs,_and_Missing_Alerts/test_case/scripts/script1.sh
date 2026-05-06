#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
BASE_DIR="/home/user/nimbusflow-argocd-lab"


function test_sync_window_not_wildcard() {
    local schedule
    schedule=$(kubectl get appproject nimbusflow-prod \
        -n argocd \
        -o jsonpath='{.spec.syncWindows[0].schedule}' \
        2>/dev/null || true)

    if [ "${schedule}" = "* * * * *" ]; then
        print_status "failed" "Lab Failed: The nimbusflow-prod AppProject still has sync window schedule '* * * * *'. A deny window with this schedule is active at every minute of every day — it permanently blocks all automated syncs for every application in the project. No Git push will ever trigger a deployment. Change the schedule to '0 9 * * 1-5' with duration '9h' to restrict the deny window to business hours only."
        exit 1
    else
        print_status "success" "Lab Passed: nimbusflow-prod sync window schedule is no longer '* * * * *'."
    fi
}


function test_sync_window_correct_schedule() {
    local schedule
    schedule=$(kubectl get appproject nimbusflow-prod -n argocd -o jsonpath='{.spec.syncWindows[0].schedule}' || true)

    if [ "${schedule}" = "0 9 * * 1-5" ]; then
        print_status "success" "Lab Passed: nimbusflow-prod sync window schedule is correctly set to '0 9 * * 1-5'."
    else
        print_status "failed" "Lab Failed: sync window schedule is '${schedule:-MISSING}', expected '0 9 * * 1-5'. Update the schedule in nimbusflow-prod-project.yaml and reapply."
        exit 1
    fi
}


function test_sync_options_no_replace() {
    local sync_options
    sync_options=$(kubectl get application inference-api \
        -n argocd \
        -o jsonpath='{.spec.syncPolicy.syncOptions}' \
        2>/dev/null || true)

    if echo "${sync_options}" | grep -q "Replace=true"; then
        print_status "failed" "Lab Failed: The inference-api Application still has 'Replace=true' in its syncOptions. This causes ArgoCD to call 'kubectl replace' on every sync, reconstructing the entire resource from the Git manifest. Any field not present in Git — such as fields written by the HPA controller or injected by admission webhooks — is silently deleted. This causes HPA crash-loops and potential downtime. Remove 'Replace=true' and add 'ServerSideApply=true' instead."
        exit 1
    else
        print_status "success" "Lab Passed: inference-api syncOptions does not contain 'Replace=true'."
    fi
}

test_sync_window_not_wildcard
test_sync_window_correct_schedule
test_sync_options_no_replace
print_status "success" "Lab Passed: nimbusflow-prod sync window schedule is correctly set and no longer a wildcard, and inference-api does not use Replace=true in syncOptions."
exit 0

