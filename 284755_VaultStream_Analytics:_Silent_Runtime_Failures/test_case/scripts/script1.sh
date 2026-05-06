#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR
NAMESPACE="vaultstream-prod"


function test_db_password_not_double_encoded() {
    local stored_b64 decoded_once decoded_twice
    stored_b64=$(kubectl get secret db-credentials -n "$NAMESPACE" -o jsonpath='{.data.password}')

    if [ -z "$stored_b64" ]; then
        print_status "failed" "Lab Failed: Secret 'db-credentials' has no key 'password' in .data."
        exit 1
    fi
    decoded_once=$(echo "$stored_b64" | base64 -d 2>/dev/null)
    decoded_twice=$(echo "$decoded_once" | base64 -d 2>/dev/null || true)

    if [ -n "$decoded_twice" ] && [ "$decoded_twice" != "$decoded_once" ]; then
        print_status "failed" "Lab Failed: Secret 'db-credentials' key 'password' is double-base64-encoded. The application will receive the base64 string itself as its password instead of the plaintext credential. Store only a single layer of base64 encoding."
        exit 1
    fi
    print_status "success" "Lab Passed: Secret 'db-credentials' key 'password' is correctly single-encoded."
}


function test_event_ingestor_secret_key() {
    local key_ref
    key_ref=$(kubectl get deployment event-ingestor -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}{" "}{.valueFrom.secretKeyRef.key}{"\n"}{end}' | grep "^DB_PASSWORD " | awk '{print $2}')

    if [ "$key_ref" != "password" ]; then
        print_status "failed" "Lab Failed: event-ingestor env var DB_PASSWORD uses secretKeyRef.key='${key_ref:-MISSING}'. Must be 'password' — the key 'passwd' does not exist in db-credentials."
        exit 1
    fi
    print_status "success" "Lab Passed: event-ingestor DB_PASSWORD correctly references secretKeyRef.key=password."
}


function test_worker_config_has_broker_address() {
    local value
    value=$(kubectl get configmap worker-config -n "$NAMESPACE" -o jsonpath='{.data.broker_address}')

    if [ -z "$value" ]; then
        print_status "failed" "Lab Failed: ConfigMap 'worker-config' does not contain key 'broker_address' or the value is empty. The transform-worker Deployment references this key with optional: false — without it the pod cannot start."
        exit 1
    fi
    print_status "success" "Lab Passed: ConfigMap 'worker-config' contains key 'broker_address' (value: $value)."
}

test_db_password_not_double_encoded
test_event_ingestor_secret_key
test_worker_config_has_broker_address
print_status "success" "Lab Passed: db-credentials password is single-encoded and correctly referenced, and worker-config contains broker_address. Proceeding to check transform-worker env vars..."
exit 0

