#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="medisecure-prod"
DEPLOYMENT="patient-data-processor"
LABEL_SELECTOR="app=patient-data-processor"

function test_readonly_root_filesystem() {
    local readonly_fs
    readonly_fs=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null)
    
    if [ "$readonly_fs" != "true" ]; then
        print_status "failed" "Lab Failed: Deployment missing readOnlyRootFilesystem: true. Found: '$readonly_fs'"
        exit 1
    fi
    
    print_status "success" "Lab Passed: Deployment has readOnlyRootFilesystem: true."
}

function test_seccomp_profile() {
    local seccomp_type
    seccomp_type=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}' 2>/dev/null)
    
    if [ "$seccomp_type" != "RuntimeDefault" ]; then
        print_status "failed" "Lab Failed: Deployment missing seccompProfile type: RuntimeDefault. Found: '$seccomp_type'"
        exit 1
    fi
    
    print_status "success" "Lab Passed: Deployment has seccompProfile: RuntimeDefault."
}

function test_pods_running() {
    kubectl wait --for=condition=ready pod -l "$LABEL_SELECTOR" -n "$NAMESPACE" --timeout=60s 2>/dev/null || true
    
    local ready_pods
    ready_pods=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" --field-selector=status.phase=Running -o json | jq '.items | length')
    
    if [ "$ready_pods" -lt 1 ]; then
        print_status "failed" "Lab Failed: No pods are running. Check deployment status."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Pods are running successfully ($ready_pods pods)."
}

function test_pod_exec_nonroot() {
    local pod
    pod=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod" ]; then
        print_status "failed" "Lab Failed: No pod found to test."
        exit 1
    fi
    
    local uid
    uid=$(kubectl exec "$pod" -n "$NAMESPACE" -- id -u 2>/dev/null)
    
    if [ -z "$uid" ]; then
        print_status "failed" "Lab Failed: Could not check user ID in pod."
        exit 1
    fi
    
    if [ "$uid" -eq 0 ] 2>/dev/null; then
        print_status "failed" "Lab Failed: Pod is running as root (UID 0). Must run as non-root."
        exit 1
    fi
    print_status "success" "Lab Passed: Pod is running as non-root user (UID: $uid)."
}

test_readonly_root_filesystem
test_seccomp_profile
test_pods_running
test_pod_exec_nonroot

print_status "success" "Lab Passed: All Pod Security tests completed successfully. HIPAA compliant!"
exit 0
