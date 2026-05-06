#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="cloudbank-prod"
PVC_NAME="postgres-pvc"
DEPLOYMENT="postgres-db"
LABEL_SELECTOR="app=postgres"

function test_pvc_storage_size() {
    local requested_storage
    requested_storage=$(kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.resources.requests.storage}')
    
    if [ "$requested_storage" != "5Gi" ]; then
        print_status "failed" "Lab Failed: PVC storage size is incorrect (expected: 5Gi, found: $requested_storage)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: PVC requests correct storage size (5Gi)."
}

function test_pvc_access_mode() {
    local access_mode
    access_mode=$(kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.accessModes[0]}')
    
    if [ "$access_mode" != "ReadWriteOnce" ]; then
        print_status "failed" "Lab Failed: PVC access mode is incorrect (expected: ReadWriteOnce, found: $access_mode)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: PVC has correct access mode (ReadWriteOnce)."
}

test_pvc_storage_size
test_pvc_access_mode

exit 0
