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


function test_namespace_exists() {
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        print_status "failed" "Lab Failed: Namespace techflow-prod does not exist."
        exit 1
    fi
    print_status "success" "Lab Passed: Namespace techflow-prod exists."
}


function test_configmap_exists() {
    if ! kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" >/dev/null 2>&1; then
        print_status "failed" "Lab Failed: ConfigMap gateway-config does not exist."
        exit 1
    fi
    print_status "success" "Lab Passed: ConfigMap gateway-config exists."
}


function test_deployment_exists() {
    if ! kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null 2>&1; then
        print_status "failed" "Lab Failed: Deployment payment-gateway does not exist."
        exit 1
    fi
    print_status "success" "Lab Passed: Deployment payment-gateway exists."
}


test_namespace_exists
test_configmap_exists
test_deployment_exists


exit 0
