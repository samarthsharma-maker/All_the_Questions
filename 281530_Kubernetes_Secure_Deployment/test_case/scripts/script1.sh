#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="secure-deploy-prod"
DEPLOYMENT="microservice-app"
SERVICE="microservice-svc"

function test_deployment_exists() {
    kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_status "failed" "Deployment microservice-app does not exist."
        exit 1
    fi
    print_status "success" "Deployment exists."
}

function test_service_exists() {
    kubectl get service "$SERVICE" -n "$NAMESPACE" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_status "failed" "Service microservice-svc does not exist."
        exit 1
    fi
    print_status "success" "Service exists."
}

test_deployment_exists
test_service_exists

print_status "success" "Lab Passed: Both Deployment and Service exist."
exit 0
