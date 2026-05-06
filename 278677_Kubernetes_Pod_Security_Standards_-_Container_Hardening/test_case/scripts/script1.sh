#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="medisecure-prod"
DEPLOYMENT="patient-data-processor"
LABEL_SELECTOR="app=patient-data-processor"

function test_namespace_has_pod_security_labels() {
    local enforce_label
    enforce_label=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
    
    if [ "$enforce_label" != "restricted" ]; then
        print_status "failed" "Lab Failed: Namespace does not have pod-security.kubernetes.io/enforce=restricted label. Found: '$enforce_label'"
        exit 1
    fi
    
    print_status "success" "Lab Passed: Namespace has Pod Security Admission enabled (enforce=restricted)."
}

function test_deployment_runs_as_nonroot() {
    local run_as_nonroot_pod run_as_nonroot_container
    
    run_as_nonroot_pod=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}' 2>/dev/null)
    
    run_as_nonroot_container=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].securityContext.runAsNonRoot}' 2>/dev/null)
    
    if [ "$run_as_nonroot_pod" != "true" ] && [ "$run_as_nonroot_container" != "true" ]; then
        print_status "failed" "Lab Failed: Deployment missing runAsNonRoot: true in securityContext."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Deployment has runAsNonRoot: true."
}

function test_deployment_has_nonroot_uid() {
    local run_as_user_pod run_as_user_container
    
    run_as_user_pod=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.securityContext.runAsUser}' 2>/dev/null)
    
    run_as_user_container=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].securityContext.runAsUser}' 2>/dev/null)
    
    if [ -z "$run_as_user_pod" ] && [ -z "$run_as_user_container" ]; then
        print_status "failed" "Lab Failed: Deployment missing runAsUser setting."
        exit 1
    fi
    
    local uid="${run_as_user_container:-$run_as_user_pod}"
    
    if [ "$uid" -eq 0 ] 2>/dev/null; then
        print_status "failed" "Lab Failed: Deployment runAsUser is 0 (root). Must be > 0."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Deployment has runAsUser > 0 (non-root UID: $uid)."
}

test_namespace_has_pod_security_labels
test_deployment_runs_as_nonroot
test_deployment_has_nonroot_uid


exit 0