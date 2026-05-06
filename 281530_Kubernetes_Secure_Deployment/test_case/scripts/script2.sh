#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="secure-deploy-prod"
CONFIGMAP="app-config"

function test_configmap_exists() {
    kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_status "failed" "ConfigMap app-config does not exist."
        exit 1
    fi
    print_status "success" "ConfigMap exists."
}

function test_app_properties_file_exists() {
    kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" \
        -o jsonpath='{.data.app\.properties}' >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        print_status "failed" "ConfigMap missing app.properties file."
        exit 1
    fi
    print_status "success" "app.properties file exists."
}

function test_configmap_key_values_exist() {
    max=$(kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.MAX_CONNECTIONS}')
    ttl=$(kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.CACHE_TTL}')

    if [ "$max" != "100" ] || [ "$ttl" != "3600" ]; then
        print_status "failed" "ConfigMap key-value data incorrect."
        exit 1
    fi
    print_status "success" "ConfigMap key-value data correct."
}

test_configmap_exists
test_app_properties_file_exists
test_configmap_key_values_exist

print_status "success" "All ConfigMap tests passed."
exit 0
