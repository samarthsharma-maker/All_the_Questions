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

function test_password_uses_secretkeyref() {
    local secret_name
    secret_name=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath="{.spec.template.spec.containers[0].env[?(@.name=='DB_PASSWORD')].valueFrom.secretKeyRef.name}" 2>/dev/null)
    
    # Check if secretKeyRef is used at all
    if [ -z "$secret_name" ]; then
        print_status "failed" "Lab Failed: DB_PASSWORD does not use secretKeyRef. Password is hardcoded (SECURITY VIOLATION)."
        exit 1
    fi
    
    # Check if it references the correct Secret
    if [ "$secret_name" != "$SECRET" ]; then
        print_status "failed" "Lab Failed: DB_PASSWORD uses secretKeyRef but references wrong Secret (expected: $SECRET, found: $secret_name)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: DB_PASSWORD uses secretKeyRef from '$SECRET'."
}

function test_no_hardcoded_password() {
    local hardcoded_value
    hardcoded_value=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath="{.spec.template.spec.containers[0].env[?(@.name=='DB_PASSWORD')].value}" 2>/dev/null)
    
    if [ -n "$hardcoded_value" ]; then
        print_status "failed" "Lab Failed: DB_PASSWORD has hardcoded value (SECURITY VIOLATION). Must use secretKeyRef."
        exit 1
    fi
    
    print_status "success" "Lab Passed: DB_PASSWORD is not hardcoded."
}

test_password_uses_secretkeyref
test_no_hardcoded_password

print_status "success" "Lab Passed: Secret verification completed successfully."
exit 0