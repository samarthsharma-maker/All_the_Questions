#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
BASE_DIR="/home/user/nimbusflow-argocd-lab"


function test_sync_options_server_side_apply() {
    local sync_options
    sync_options=$(kubectl get application inference-api \
        -n argocd \
        -o jsonpath='{.spec.syncPolicy.syncOptions}' \
        2>/dev/null || true)

    if echo "${sync_options}" | grep -q "ServerSideApply=true"; then
        print_status "success" "Lab Passed: inference-api syncOptions correctly contains 'ServerSideApply=true'."
    else
        print_status "failed" "Lab Failed: The inference-api Application does not have 'ServerSideApply=true' in its syncOptions. Server-Side Apply allows ArgoCD to update only the fields it owns, leaving controller-managed fields (HPA replica counts, injected sidecars) untouched. Add 'ServerSideApply=true' to the syncOptions list in inference-api.yaml and reapply."
        exit 1
    fi
}


function test_notifications_trigger_correct_template() {
    local trigger_def
    trigger_def=$(kubectl get configmap argocd-notifications-cm \
        -n argocd \
        -o jsonpath='{.data.trigger\.on-sync-failed}' \
        2>/dev/null || true)

    if echo "${trigger_def}" | grep -q "app-sync-failed-notify"; then
        print_status "failed" "Lab Failed: The 'on-sync-failed' trigger in argocd-notifications-cm still references template 'app-sync-failed-notify'. This template name does not exist in the ConfigMap — the notifications controller resolves template names at send time and silently drops any notification whose template cannot be found. No sync failure alerts will ever reach Slack. Change the send value from '[app-sync-failed-notify]' to '[app-sync-failed]' to match the defined template."
        exit 1
    else
        print_status "success" "Lab Passed: on-sync-failed trigger no longer references the broken template name 'app-sync-failed-notify'."
    fi
}


function test_notifications_template_exists() {
    local cm_data
    cm_data=$(kubectl get configmap argocd-notifications-cm \
        -n argocd \
        -o jsonpath='{.data}' \
        2>/dev/null || true)

    if echo "${cm_data}" | grep -q "template.app-sync-failed"; then
        print_status "success" "Lab Passed: argocd-notifications-cm defines the 'app-sync-failed' template."
    else
        print_status "failed" "Lab Failed: The argocd-notifications-cm ConfigMap does not define a key 'template.app-sync-failed'. The template must exist for the trigger to send notifications. Do not rename or remove the template — only fix the trigger's send value to reference it correctly."
        exit 1
    fi
}

test_sync_options_server_side_apply
test_notifications_trigger_correct_template
test_notifications_template_exists

print_status "success" "All Lab Tests Passed: nimbusflow-prod sync window schedule, inference-api ServerSideApply, and notifications trigger template reference are all correctly configured."
exit 0