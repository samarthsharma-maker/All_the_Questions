#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="techflow-prod"
CONFIGMAP="gateway-config"
DEPLOYMENT="payment-gateway"
LABEL_SELECTOR="app=payment-gateway"
REQUIRED_KEYS="SERVICE_NAME SERVICE_VERSION DATABASE_URL REDIS_URL MAX_CONNECTIONS TIMEOUT_SECONDS"


function test_configmap_file_exists() {
    if ! kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" \
        -o jsonpath='{.data.gateway\.conf}' >/dev/null 2>&1; then
        print_status "failed" "Lab Failed: gateway.conf missing in ConfigMap."
        exit 1
    fi
    print_status "success" "Lab Passed: gateway.conf exists in ConfigMap."
}

function test_configmap_required_keys() {
    CONF=$(kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.gateway\.conf}')
    for key in $REQUIRED_KEYS; do
        if ! echo "$CONF" | grep -q "^$key="; then
            print_status "failed" "Lab Failed: Missing required config key: $key"
            exit 1
        fi
    done
    print_status "success" "Lab Passed: All required configuration keys are present."
}

test_configmap_file_exists
test_configmap_required_keys
exit 0