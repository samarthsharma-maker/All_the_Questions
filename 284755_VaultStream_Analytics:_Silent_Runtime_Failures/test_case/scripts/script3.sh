#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR
NAMESPACE="vaultstream-prod"

function test_route_dispatcher_tls_volume_ref() {
    local secret_ref
    secret_ref=$(kubectl get deployment route-dispatcher -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.volumes[*]}{.name}{" "}{.secret.secretName}{"\n"}{end}' | grep "^broker-tls-vol " | awk '{print $2}')

    if [ "$secret_ref" != "broker-tls-secret" ]; then
        print_status "failed" "Lab Failed: route-dispatcher volume 'broker-tls-vol' references secret '${secret_ref:-MISSING}'. Must reference 'broker-tls-secret'."
        exit 1
    fi

    if ! kubectl get secret broker-tls-secret -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: route-dispatcher references 'broker-tls-secret' but it still does not exist in '$NAMESPACE'."
        exit 1
    fi
    print_status "success" "Lab Passed: route-dispatcher 'broker-tls-vol' correctly references 'broker-tls-secret' in '$NAMESPACE'."
}


function test_audit_logger_signing_key_ref() {
    local key_ref
    key_ref=$(kubectl get deployment audit-logger -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}{" "}{.valueFrom.secretKeyRef.key}{"\n"}{end}' | grep "^SIGNING_KEY " | awk '{print $2}')

    if [ "$key_ref" != "signing_key" ]; then
        print_status "failed" "Lab Failed: audit-logger env var SIGNING_KEY uses secretKeyRef.key='${key_ref:-MISSING}'. Must be 'signing_key' — the key 'key' does not exist in the audit-signing-key Secret."
        exit 1
    fi
    print_status "success" "Lab Passed: audit-logger SIGNING_KEY correctly references secretKeyRef.key=signing_key."
}


function test_feature_flags_has_enable_audit_log() {
    local value
    value=$(kubectl get configmap pipeline-feature-flags -n "$NAMESPACE" -o jsonpath='{.data.enable_audit_log}')

    if [ -z "$value" ]; then
        print_status "failed" "Lab Failed: ConfigMap 'pipeline-feature-flags' does not contain key 'enable_audit_log'. The audit-logger Deployment references this key with optional: false — without it the pod cannot start."
        exit 1
    fi

    if [ "$value" != "true" ]; then
        print_status "failed" "Lab Failed: ConfigMap 'pipeline-feature-flags' key 'enable_audit_log' has value '${value}'. Must be 'true' to enable audit logging."
        exit 1
    fi
    print_status "success" "Lab Passed: ConfigMap 'pipeline-feature-flags' contains enable_audit_log=true."
}


test_route_dispatcher_tls_volume_ref
test_audit_logger_signing_key_ref
test_feature_flags_has_enable_audit_log
print_status "success" "Lab Passed: route-dispatcher TLS volume reference, audit-logger signing key reference, and audit log feature flag are all correct. Proceeding to check audit-logger env var name and reference..."
exit 0