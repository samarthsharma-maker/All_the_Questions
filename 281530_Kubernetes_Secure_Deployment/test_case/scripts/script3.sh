#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="secure-deploy-prod"
SECRET="app-secrets"

function test_secret_exists() {
    kubectl get secret "$SECRET" -n "$NAMESPACE" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_status "failed" "Secret app-secrets does not exist."
        exit 1
    fi
    print_status "success" "Secret exists."
}

function test_secret_keys_exist() {
    keys=$(kubectl get secret "$SECRET" -n "$NAMESPACE" -o jsonpath='{.data}')

    for key in db-username db-password api-key; do
        echo "$keys" | grep -q "$key"
        if [ $? -ne 0 ]; then
            print_status "failed" "Secret missing key: $key"
            exit 1
        fi
    done

    print_status "success" "All required secret keys exist."
}

test_secret_exists
test_secret_keys_exist

print_status "success" "All secret validations passed."
exit 0
