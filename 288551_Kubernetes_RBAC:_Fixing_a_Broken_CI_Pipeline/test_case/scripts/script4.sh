#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

SA_NAME="ci-runner"
NAMESPACES=("dev" "staging")

function test_resourcequotas_are_reasonable() {
    for ns in "${NAMESPACES[@]}"; do
        local quota_name="pipeline-quota"
        if ! kubectl get resourcequota "$quota_name" -n "$ns" &>/dev/null; then
            print_status "failed" "Lab Failed: Resource quota configuration incomplete. Check namespace constraints."
            exit 1
        fi

        # Check that pod quota is at least 10
        local pod_limit
        pod_limit=$(kubectl get resourcequota "$quota_name" -n "$ns" -o jsonpath='{.spec.hard.pods}')
        if [ "${pod_limit//[^0-9]/}" -lt 10 ]; then
            print_status "failed" "Lab Failed: Resource quota limits are insufficient. Review hard limits."
            exit 1
        fi

        # Check that memory quota is at least 512Mi
        local mem_limit
        mem_limit=$(kubectl get resourcequota "$quota_name" -n "$ns" -o jsonpath='{.spec.hard["requests.memory"]}')
        if [[ "$mem_limit" == *"Mi" ]]; then
            mem_value="${mem_limit//Mi/}"
            if [ "${mem_value//[^0-9]/}" -lt 512 ]; then
                print_status "failed" "Lab Failed: Resource limits configuration error. Adjust quota constraints."
                exit 1
            fi
        fi
    done

    print_status "success" "Lab Passed: Resource quotas verified."
}

function test_can_get_pod_logs() {
    for ns in "${NAMESPACES[@]}"; do
        local sa_ref="system:serviceaccount:${ns}:${SA_NAME}"
        local result
        result=$(kubectl auth can-i get pods/log --as="$sa_ref" -n "$ns" 2>/dev/null)

        if [ "$result" != "yes" ]; then
            print_status "failed" "Lab Failed: Permission verification failed. Check authorization rules."
            exit 1
        fi
    done

    print_status "success" "Lab Passed: Log access permissions verified."
}

function test_cannot_delete_pods() {
    for ns in "${NAMESPACES[@]}"; do
        local sa_ref="system:serviceaccount:${ns}:${SA_NAME}"
        local result
        result=$(kubectl auth can-i delete pods --as="$sa_ref" -n "$ns" 2>/dev/null)

        if [ "$result" != "no" ]; then
            print_status "failed" "Lab Failed: Permission scope violation detected. Verify security constraints."
            exit 1
        fi
    done

    print_status "success" "Lab Passed: Destructive operation restrictions verified."
}

function test_cannot_create_pods() {
    for ns in "${NAMESPACES[@]}"; do
        local sa_ref="system:serviceaccount:${ns}:${SA_NAME}"
        local result
        result=$(kubectl auth can-i create pods --as="$sa_ref" -n "$ns" 2>/dev/null)

        if [ "$result" != "no" ]; then
            print_status "failed" "Lab Failed: Permission scope violation detected. Verify security constraints."
            exit 1
        fi
    done

    print_status "success" "Lab Passed: Permission scope constraints verified."
}

function test_cannot_list_pods_without_rbac() {
    local unauthorized_sa="system:serviceaccount:dev:default"
    local result
    result=$(kubectl auth can-i get pods --as="$unauthorized_sa" -n "dev" 2>/dev/null || true)

    if [ "$result" == "yes" ]; then
        print_status "warning" "Warning: Unexpected permission detected. Review RBAC scope."
    else
        print_status "success" "Lab Passed: Permission isolation verified."
    fi
}

test_resourcequotas_are_reasonable
test_can_get_pod_logs
test_cannot_delete_pods
test_cannot_create_pods
test_cannot_list_pods_without_rbac

print_status "success" "Lab Passed: All RBAC and resource configurations verified."
exit 0