#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

ROLE_NAME="ci-reader"
NAMESPACES=("dev" "staging")

function test_roles_exist_in_both_namespaces() {
    for ns in "${NAMESPACES[@]}"; do
        if ! kubectl get role "$ROLE_NAME" -n "$ns" &>/dev/null; then
            print_status "failed" "Lab Failed: Role configuration incomplete. Check all required resources."
            exit 1
        fi
    done
    print_status "success" "Lab Passed: Role existence verified."
}

function test_role_has_correct_resources() {
    for ns in "${NAMESPACES[@]}"; do
        local resources
        resources=$(kubectl get role "$ROLE_NAME" -n "$ns" -o jsonpath='{.rules[*].resources[*]}')

        if [[ "$resources" != *"pods"* ]]; then
            print_status "failed" "Lab Failed: Role permission configuration incorrect. Inspect role rules."
            exit 1
        fi

        if [[ "$resources" != *"pods/log"* ]]; then
            print_status "failed" "Lab Failed: Role permission configuration incomplete. Review required resources."
            exit 1
        fi
    done

    print_status "success" "Lab Passed: Role resources verified."
}

function test_role_has_correct_verbs() {
    for ns in "${NAMESPACES[@]}"; do
        local verbs
        verbs=$(kubectl get role "$ROLE_NAME" -n "$ns" -o jsonpath='{.rules[*].verbs[*]}')

        for required_verb in "get" "list" "watch"; do
            if [[ "$verbs" != *"$required_verb"* ]]; then
                print_status "failed" "Lab Failed: Role permissions mismatch. Verify verb configuration."
                exit 1
            fi
        done
    done

    print_status "success" "Lab Passed: Role verbs verified."
}

function test_role_has_no_destructive_verbs() {
    for ns in "${NAMESPACES[@]}"; do
        local verbs
        verbs=$(kubectl get role "$ROLE_NAME" -n "$ns" -o jsonpath='{.rules[*].verbs[*]}')

        for bad_verb in "create" "delete" "update" "patch"; do
            if [[ "$verbs" == *"$bad_verb"* ]]; then
                print_status "failed" "Lab Failed: Role has excessive permissions. Review security constraints."
                exit 1
            fi
        done
    done

    print_status "success" "Lab Passed: Role permission scope verified."
}

test_roles_exist_in_both_namespaces
test_role_has_correct_resources
test_role_has_correct_verbs
test_role_has_no_destructive_verbs

print_status "success" "Lab Passed: Role configuration verified."
exit 0