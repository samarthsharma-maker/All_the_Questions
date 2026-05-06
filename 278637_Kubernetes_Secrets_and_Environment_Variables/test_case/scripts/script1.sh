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


function test_secret_exists() {
    if ! kubectl get secret "$SECRET" -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: Secret '$SECRET' does not exist in namespace '$NAMESPACE'."
        exit 1
    fi
    print_status "success" "Lab Passed: Secret '$SECRET' exists."
}

function test_secret_has_password_key() {
    local secret_keys
    secret_keys=$(kubectl get secret "$SECRET" -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null)
    
    if ! echo "$secret_keys" | grep -q "^DB_PASSWORD$"; then
        print_status "failed" "Lab Failed: Secret '$SECRET' does not contain 'DB_PASSWORD' key."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Secret contains 'DB_PASSWORD' key."
}





test_secret_exists
test_secret_has_password_key

print_status "success" "Lab Passed: Secret verification completed successfully."
exit 0