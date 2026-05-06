#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE_PROD="production"
NAMESPACE_DEV="development"
DEVELOPER_USER="developer-user"
CICD_SA="system:serviceaccount:production:cicd-deployer"

function test_no_cluster_admin() {
    if kubectl get clusterrolebinding developer-admin-binding &>/dev/null; then
        print_status "failed" "Lab Failed: ClusterRoleBinding 'developer-admin-binding' still exists. Must be deleted!"
        exit 1
    fi
    
    local can_delete_ns
    can_delete_ns=$(kubectl auth can-i delete namespaces --as="$DEVELOPER_USER" 2>/dev/null)
    
    if [ "$can_delete_ns" == "yes" ]; then
        print_status "failed" "Lab Failed: Developer can still delete namespaces (has cluster-admin or ClusterRole)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Developer does not have cluster-admin privileges."
}

function test_developer_role_exists() {
    if ! kubectl get role developer-role -n "$NAMESPACE_DEV" &>/dev/null; then
        print_status "failed" "Lab Failed: Role 'developer-role' does not exist in namespace '$NAMESPACE_DEV'."
        exit 1
    fi
    
    if ! kubectl get rolebinding developer-binding -n "$NAMESPACE_DEV" &>/dev/null; then
        print_status "failed" "Lab Failed: RoleBinding 'developer-binding' does not exist in namespace '$NAMESPACE_DEV'."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Developer role and binding exist in development namespace."
}

test_no_cluster_admin
test_developer_role_exists


exit 0