#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR
NAMESPACE="vaultstream-prod"

function test_audit_logger_env_var_name() {
    local env_name key_ref

    env_name=$(kubectl get deployment audit-logger -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}{"\n"}{end}' | grep "^ENABLE_AUDIT_LOG$")

    if [ -z "$env_name" ]; then
        print_status "failed" "Lab Failed: audit-logger has no env var named 'ENABLE_AUDIT_LOG'. The application reads from this exact name — injecting under 'AUDIT_LOG_ENABLED' means audit logging stays silently disabled even after the ConfigMap key is fixed."
        exit 1
    fi

    key_ref=$(kubectl get deployment audit-logger -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}{" "}{.valueFrom.configMapKeyRef.key}{"\n"}{end}' | grep "^ENABLE_AUDIT_LOG " | awk '{print $2}')

    if [ "$key_ref" != "enable_audit_log" ]; then
        print_status "failed" "Lab Failed: audit-logger env var ENABLE_AUDIT_LOG uses configMapKeyRef.key='${key_ref:-MISSING}'. Must be 'enable_audit_log'."
        exit 1
    fi
    print_status "success" "Lab Passed: audit-logger injects ENABLE_AUDIT_LOG from configMapKeyRef.key=enable_audit_log."
}


test_audit_logger_env_var_name
print_status "success" "Lab Passed: audit-logger env var name and reference are correct. All tests passed!"
exit 0