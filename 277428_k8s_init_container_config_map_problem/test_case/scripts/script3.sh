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

#ANSWER
REQUIRED_REPLICAS=3


function test_deployment_replicas() {
    local deployment_name=$1
    local namespace=$2
    local replicas_req=$3

    REPLICAS=$(kubectl get deployment "$deployment_name" -n "$namespace" -o jsonpath='{.spec.replicas}')
    if [ "$REPLICAS" -ne "$replicas_req" ]; then
        print_status "failed" "Lab Failed: Deployment replica count is not $replicas_req."
        exit 1
    fi
    print_status "success" "Lab Passed: Deployment replica count is correct."
}


function test_init_container_exists() {
    local deployment_name=$1
    local namespace=$2

    if ! kubectl get deployment "$deployment_name" -n "$namespace" \
        -o jsonpath='{.spec.template.spec.initContainers[*].name}' | grep -q "config-guardian"; then
        print_status "failed" "Lab Failed: Init container config-guardian not found."
        exit 1
    fi
    print_status "success" "Lab Passed: Init container config-guardian exists."
}


test_deployment_replicas "$DEPLOYMENT" "$NAMESPACE" "$REQUIRED_REPLICAS"
test_init_container_exists "$DEPLOYMENT" "$NAMESPACE"
exit 0