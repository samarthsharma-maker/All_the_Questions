#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="cloudbank-prod"
PVC_NAME="postgres-pvc"
DEPLOYMENT="postgres-db"
LABEL_SELECTOR="app=postgres"

function test_deployment_uses_pvc() {
    # Check if deployment uses persistentVolumeClaim
    local pvc_claim_name
    pvc_claim_name=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.volumes[?(@.name=="postgres-storage")].persistentVolumeClaim.claimName}' 2>/dev/null)
    
    if [ -z "$pvc_claim_name" ]; then
        print_status "failed" "Lab Failed: Deployment does not use persistentVolumeClaim. Still using emptyDir?"
        exit 1
    fi
    
    if [ "$pvc_claim_name" != "$PVC_NAME" ]; then
        print_status "failed" "Lab Failed: Deployment references wrong PVC (expected: $PVC_NAME, found: $pvc_claim_name)."
        exit 1
    fi
    
    # Verify emptyDir is NOT being used
    local empty_dir_check
    empty_dir_check=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.volumes[?(@.name=="postgres-storage")].emptyDir}' 2>/dev/null)
    
    if [ -n "$empty_dir_check" ]; then
        print_status "failed" "Lab Failed: Deployment still uses emptyDir. Must use persistentVolumeClaim."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Deployment uses PVC '$PVC_NAME' (not emptyDir)."
}

function test_pod_running_with_pv() {
    # Wait for pod to be ready
    for i in {1..120}; do
        POD_READY=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" \
            -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
        
        if [ "$POD_READY" == "true" ]; then
            break
        fi
        sleep 1
    done
    
    if [ "$POD_READY" != "true" ]; then
        print_status "failed" "Lab Failed: Pod is not ready. Check pod status and events."
        exit 1
    fi
    
    # Verify pod has the volume mounted
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" -o jsonpath='{.items[0].metadata.name}')
    
    local volume_mount
    volume_mount=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" \
        -o jsonpath='{.spec.volumes[?(@.name=="postgres-storage")].persistentVolumeClaim.claimName}' 2>/dev/null)
    
    if [ "$volume_mount" != "$PVC_NAME" ]; then
        print_status "failed" "Lab Failed: Pod does not have PVC mounted correctly."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Pod is running with persistent volume mounted."
}

test_deployment_uses_pvc
test_pod_running_with_pv

print_status "success" "Lab Passed: All tests completed successfully. Deployment is properly using persistent storage!"
exit 0
