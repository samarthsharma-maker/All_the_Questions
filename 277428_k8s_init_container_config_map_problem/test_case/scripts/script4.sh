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


function test_pods_running() {
    if kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" \
        | grep -v NAME | grep -vq Running; then
        print_status "failed" "Lab Failed: One or more pods are not running."
        exit 1
    fi
    print_status "success" "Lab Passed: All pods are running."
}


function test_init_container_logs() {
    POD=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" -o jsonpath='{.items[0].metadata.name}')
    if ! kubectl logs "$POD" -n "$NAMESPACE" -c config-guardian \
        | grep -q "Configuration validation completed"; then
        print_status "failed" "Lab Failed: Init container validation did not succeed."
        exit 1
    fi
    print_status "success" "Lab Passed: Init container validation succeeded."
}

function test_config_access_main_container() {
    POD=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" -o jsonpath='{.items[0].metadata.name}')
    if ! kubectl exec -n "$NAMESPACE" "$POD" -c gateway -- \
        test -f /etc/techflow/gateway.conf; then
        print_status "failed" "Lab Failed: Configuration file not accessible in main container."
        exit 1
    fi
    print_status "success" "Lab Passed: Configuration file accessible in main container."
}

test_pods_running
test_init_container_logs
test_config_access_main_container
exit 0