#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

SA_NAME="ci-runner"
BINDING_NAME="ci-runner-binding"
NAMESPACES=("dev" "staging")

function test_rolebindings_exist_in_both_namespaces() {
    for ns in "${NAMESPACES[@]}"; do
        if ! kubectl get rolebinding "$BINDING_NAME" -n "$ns" &>/dev/null; then
            print_status "failed" "Lab Failed: RoleBinding configuration incomplete. Check all namespaces."
            exit 1
        fi
    done
    print_status "success" "Lab Passed: RoleBinding existence verified."
}

function test_rolebinding_binds_correct_subject() {
    for ns in "${NAMESPACES[@]}"; do
        local subject_name subject_namespace
        subject_name=$(kubectl get rolebinding "$BINDING_NAME" -n "$ns" -o jsonpath='{.subjects[0].name}')
        subject_namespace=$(kubectl get rolebinding "$BINDING_NAME" -n "$ns" -o jsonpath='{.subjects[0].namespace}')

        if [ "$subject_name" != "$SA_NAME" ]; then
            print_status "failed" "Lab Failed: RoleBinding subject mismatch. Verify ServiceAccount reference."
            exit 1
        fi

        if [ "$subject_namespace" != "$ns" ]; then
            print_status "failed" "Lab Failed: RoleBinding namespace reference incorrect. Check subject configuration."
            exit 1
        fi
    done

    print_status "success" "Lab Passed: RoleBinding subject references verified."
}

function test_rolebinding_references_correct_role() {
    for ns in "${NAMESPACES[@]}"; do
        local role_ref
        role_ref=$(kubectl get rolebinding "$BINDING_NAME" -n "$ns" -o jsonpath='{.roleRef.name}')

        if [ "$role_ref" != "ci-reader" ]; then
            print_status "failed" "Lab Failed: RoleBinding role reference incorrect. Verify roleRef configuration."
            exit 1
        fi
    done

    print_status "success" "Lab Passed: RoleBinding role references verified."
}

function test_can_get_pods() {
    for ns in "${NAMESPACES[@]}"; do
        local sa_ref="system:serviceaccount:${ns}:${SA_NAME}"
        local result
        result=$(kubectl auth can-i get pods --as="$sa_ref" -n "$ns" 2>/dev/null)

        if [ "$result" != "yes" ]; then
            print_status "failed" "Lab Failed: Permission check failed. Review RBAC bindings."
            exit 1
        fi
    done

    print_status "success" "Lab Passed: ServiceAccount permissions verified."
}

test_rolebindings_exist_in_both_namespaces
test_rolebinding_binds_correct_subject
test_rolebinding_references_correct_role
test_can_get_pods

print_status "success" "Lab Passed: RoleBinding configuration verified."
exit 0