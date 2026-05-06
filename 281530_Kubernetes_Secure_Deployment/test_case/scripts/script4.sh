#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="secure-deploy-prod"
DEPLOYMENT="microservice-app"

function test_configmap_volume_mounted() {
    mount=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[*].mountPath}')

    if [[ "$mount" != *"/etc/config"* ]]; then
        print_status "failed" "ConfigMap not mounted at /etc/config."
        exit 1
    fi
    print_status "success" "ConfigMap volume mounted."
}

function test_env_from_configmap() {
    env=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].env[*].name}')

    for var in MAX_CONNECTIONS CACHE_TTL; do
        echo "$env" | grep -q "$var"
        if [ $? -ne 0 ]; then
            print_status "failed" "Missing env var from ConfigMap: $var"
            exit 1
        fi
    done
    print_status "success" "Environment variables from ConfigMap set."
}

function test_env_from_secret() {
    env=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].env[*].name}')

    for var in DB_USERNAME DB_PASSWORD API_KEY; do
        echo "$env" | grep -q "$var"
        if [ $? -ne 0 ]; then
            print_status "failed" "Missing env var from Secret: $var"
            exit 1
        fi
    done
    print_status "success" "Environment variables from Secret set."
}

test_configmap_volume_mounted
test_env_from_configmap
test_env_from_secret

print_status "success" "Lab Passed: Deployment configuration verified successfully."
exit 0
