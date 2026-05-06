#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

SA_NAME="ci-runner"
NAMESPACES=("dev" "staging")

function test_namespaces_exist() {
    for ns in "${NAMESPACES[@]}"; do
        if ! kubectl get namespace "$ns" &>/dev/null; then
            print_status "failed" "Lab Failed: Required namespace not found. Check namespace configuration."
            exit 1
        fi
    done
    print_status "success" "Lab Passed: Required namespaces verified."
}

function test_serviceaccount_exists_in_both_namespaces() {
    for ns in "${NAMESPACES[@]}"; do
        if ! kubectl get serviceaccount "$SA_NAME" -n "$ns" &>/dev/null; then
            print_status "failed" "Lab Failed: ServiceAccount configuration issue detected. Verify your setup."
            exit 1
        fi
    done
    print_status "success" "Lab Passed: ServiceAccount presence verified."
}

function test_serviceaccount_not_in_default() {
    local sa_in_default
    sa_in_default=$(kubectl get serviceaccount "$SA_NAME" -n default --ignore-not-found 2>/dev/null)
    if [ -n "$sa_in_default" ]; then
        print_status "failed" "Lab Failed: Unexpected ServiceAccount location detected. Review namespace placement."
        exit 1
    fi
    print_status "success" "Lab Passed: ServiceAccount namespace placement verified."
}

test_namespaces_exist
test_serviceaccount_exists_in_both_namespaces
test_serviceaccount_not_in_default

print_status "success" "Lab Passed: ServiceAccount configuration verified."
exit 0
