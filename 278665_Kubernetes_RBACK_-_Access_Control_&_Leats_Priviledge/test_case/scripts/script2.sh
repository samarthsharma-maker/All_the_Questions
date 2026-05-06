#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR


NAMESPACE_PROD="production"
NAMESPACE_DEV="development"
DEVELOPER_USER="developer-user"
CICD_SA="system:serviceaccount:production:cicd-deployer"

function test_developer_can_create_in_dev() {
    local can_create_pods
    can_create_pods=$(kubectl auth can-i create pods --namespace="$NAMESPACE_DEV" --as="$DEVELOPER_USER" 2>/dev/null)
    
    if [ "$can_create_pods" != "yes" ]; then
        print_status "failed" "Lab Failed: Developer cannot create pods in development namespace. Check developer-role permissions."
        exit 1
    fi
    
    local can_create_deployments
    can_create_deployments=$(kubectl auth can-i create deployments --namespace="$NAMESPACE_DEV" --as="$DEVELOPER_USER" 2>/dev/null)
    
    if [ "$can_create_deployments" != "yes" ]; then
        print_status "failed" "Lab Failed: Developer cannot create deployments in development namespace."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Developer can create resources in development namespace."
}

function test_developer_cannot_delete_in_prod() {
    local can_delete_pods
    can_delete_pods=$(kubectl auth can-i delete pods --namespace="$NAMESPACE_PROD" --as="$DEVELOPER_USER" 2>/dev/null)
    
    if [ "$can_delete_pods" == "yes" ]; then
        print_status "failed" "Lab Failed: Developer can delete pods in production (should be read-only)."
        exit 1
    fi
    
    local can_delete_deployments
    can_delete_deployments=$(kubectl auth can-i delete deployments --namespace="$NAMESPACE_PROD" --as="$DEVELOPER_USER" 2>/dev/null)
    
    if [ "$can_delete_deployments" == "yes" ]; then
        print_status "failed" "Lab Failed: Developer can delete deployments in production (should be read-only)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Developer cannot delete resources in production."
}

test_developer_can_create_in_dev
test_developer_cannot_delete_in_prod

exit 0
