#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR
NAMESPACE="vaultstream-prod"

function test_transform_worker_env_var_name() {
    local env_name key_ref
    env_name=$(kubectl get deployment transform-worker -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}{"\n"}{end}' | grep "^BROKER_ADDRESS$")
    if [ -z "$env_name" ]; then
        print_status "failed" "Lab Failed: transform-worker has no env var named 'BROKER_ADDRESS'. The application reads from this exact name — injecting the value under 'BROKER_HOST' means the app reads an empty string while the pod stays Running."
        exit 1
    fi

    key_ref=$(kubectl get deployment transform-worker -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}{" "}{.valueFrom.configMapKeyRef.key}{"\n"}{end}' | grep "^BROKER_ADDRESS " | awk '{print $2}')
    if [ "$key_ref" != "broker_address" ]; then
        print_status "failed" "Lab Failed: transform-worker env var BROKER_ADDRESS uses configMapKeyRef.key='${key_ref:-MISSING}'. Must be 'broker_address'."
        exit 1
    fi
    print_status "success" "Lab Passed: transform-worker injects BROKER_ADDRESS from configMapKeyRef.key=broker_address."
}


function test_route_dispatcher_mount_path() {
    local mount_path
    mount_path=$(kubectl get deployment route-dispatcher -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[0].volumeMounts[*]}{.name}{" "}{.mountPath}{"\n"}{end}' | grep "^dispatcher-config-vol " | awk '{print $2}')

    if [ "$mount_path" != "/etc/dispatcher" ]; then
        print_status "failed" "Lab Failed: route-dispatcher mounts 'dispatcher-config-vol' at '${mount_path:-MISSING}'. Must be '/etc/dispatcher' — the application reads its routing table from this path. Mounting at a different path succeeds silently and the app falls back to defaults."
        exit 1
    fi
    print_status "success" "Lab Passed: route-dispatcher mounts dispatcher-config-vol at /etc/dispatcher."
}


function test_broker_tls_secret_in_correct_namespace() {
    if ! kubectl get secret broker-tls-secret -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: Secret 'broker-tls-secret' does not exist in namespace '$NAMESPACE'. Secrets are namespace-scoped — a Secret in vaultstream-staging cannot be mounted by a pod in vaultstream-prod. The pod will remain stuck in ContainerCreating."
        exit 1
    fi
    print_status "success" "Lab Passed: Secret 'broker-tls-secret' exists in namespace '$NAMESPACE'."
}

test_transform_worker_env_var_name
test_route_dispatcher_mount_path
test_broker_tls_secret_in_correct_namespace
print_status "success" "Lab Passed: transform-worker env vars, route-dispatcher mount path, and broker TLS secret namespace are all correct. Proceeding to check route-dispatcher TLS volume reference and audit-logger config..."
exit 0
