#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="healthsync-prod"
SECRET="patient-db-secret"
DEPLOYMENT="patient-api"
LABEL_SELECTOR="app=patient-api"
REQUIRED_REPLICAS=3

function test_all_pods_running() {
    local running_count
    
    # Wait up to 120 seconds for pods to be ready
    for i in {1..120}; do
        running_count=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" \
            --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        
        if [ "$running_count" -eq "$REQUIRED_REPLICAS" ]; then
            break
        fi
        sleep 1
    done
    
    if [ "$running_count" -ne "$REQUIRED_REPLICAS" ]; then
        print_status "failed" "Lab Failed: Not all pods are running (expected: $REQUIRED_REPLICAS, found: $running_count)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: All $REQUIRED_REPLICAS pods are running."
}

function test_password_populated_in_pod() {
    local pod_name
    
    # Get first running pod
    pod_name=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" \
        --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        print_status "failed" "Lab Failed: No running pods found to verify environment variable."
        exit 1
    fi
    
    # Check if DB_PASSWORD is set in pod (don't print the actual value for security)
    if ! kubectl exec "$pod_name" -n "$NAMESPACE" -- env 2>/dev/null | grep -q "^DB_PASSWORD="; then
        print_status "failed" "Lab Failed: DB_PASSWORD is not populated in pod from Secret."
        exit 1
    fi
    
    print_status "success" "Lab Passed: DB_PASSWORD is correctly populated in pods from Secret."
}

test_all_pods_running
test_password_populated_in_pod

print_status "success" "Lab Passed: All tests completed successfully. HIPAA compliance restored!"
exit 0