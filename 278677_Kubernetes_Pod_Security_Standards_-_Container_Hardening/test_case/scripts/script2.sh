#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="medisecure-prod"
DEPLOYMENT="patient-data-processor"
LABEL_SELECTOR="app=patient-data-processor"

function test_deployment_not_privileged() {
    local privileged
    privileged=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].securityContext.privileged}' 2>/dev/null)
    
    if [ "$privileged" == "true" ]; then
        print_status "failed" "Lab Failed: Deployment has privileged: true (must be false or unset)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Deployment is not privileged."
}

function test_privilege_escalation_disabled() {
    local allow_priv_esc
    allow_priv_esc=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null)
    
    if [ "$allow_priv_esc" != "false" ]; then
        print_status "failed" "Lab Failed: Deployment missing allowPrivilegeEscalation: false. Found: '$allow_priv_esc'"
        exit 1
    fi
    
    print_status "success" "Lab Passed: Deployment has allowPrivilegeEscalation: false."
}

function test_capabilities_dropped() {
    local caps_dropped
    caps_dropped=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.drop}' 2>/dev/null)
    
    if ! echo "$caps_dropped" | grep -q "ALL"; then
        print_status "failed" "Lab Failed: Deployment must drop ALL capabilities. Found: '$caps_dropped'"
        exit 1
    fi
    
    print_status "success" "Lab Passed: Deployment drops ALL capabilities."
}

test_deployment_not_privileged
test_privilege_escalation_disabled
test_capabilities_dropped
exit 0