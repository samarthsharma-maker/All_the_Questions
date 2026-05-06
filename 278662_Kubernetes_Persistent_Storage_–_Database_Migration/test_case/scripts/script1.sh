#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="cloudbank-prod"
PVC_NAME="postgres-pvc"
DEPLOYMENT="postgres-db"
LABEL_SELECTOR="app=postgres"


function test_pvc_exists() {
    if ! kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: PersistentVolumeClaim '$PVC_NAME' does not exist in namespace '$NAMESPACE'."
        exit 1
    fi
    print_status "success" "Lab Passed: PersistentVolumeClaim '$PVC_NAME' exists."
}

function test_pvc_bound() {
    local pvc_status
    
    # Wait up to 60 seconds for PVC to bind
    for i in {1..60}; do
        pvc_status=$(kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
        
        if [ "$pvc_status" == "Bound" ]; then
            break
        fi
        sleep 1
    done
    
    if [ "$pvc_status" != "Bound" ]; then
        print_status "failed" "Lab Failed: PVC is not bound (status: $pvc_status). Check storage class and PV availability."
        exit 1
    fi
    
    print_status "success" "Lab Passed: PVC is bound to a PersistentVolume."
}


test_pvc_exists
test_pvc_bound

print_status "success" "Lab Passed: All tests completed successfully. Database has persistent storage!"

exit 0