#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR


NAMESPACE_PROD="production"
NAMESPACE_DEV="development"
DEVELOPER_USER="developer-user"
CICD_SA="system:serviceaccount:production:cicd-deployer"

function test_developer_can_view_prod() {
    if ! kubectl get role prod-viewer -n "$NAMESPACE_PROD" &>/dev/null; then
        print_status "failed" "Lab Failed: Role 'prod-viewer' does not exist in namespace '$NAMESPACE_PROD'."
        exit 1
    fi
    
    local can_get_pods
    can_get_pods=$(kubectl auth can-i get pods --namespace="$NAMESPACE_PROD" --as="$DEVELOPER_USER" 2>/dev/null)
    
    if [ "$can_get_pods" != "yes" ]; then
        print_status "failed" "Lab Failed: Developer cannot view pods in production. Check prod-viewer role."
        exit 1
    fi
    
    local can_list_deployments
    can_list_deployments=$(kubectl auth can-i list deployments --namespace="$NAMESPACE_PROD" --as="$DEVELOPER_USER" 2>/dev/null)
    
    if [ "$can_list_deployments" != "yes" ]; then
        print_status "failed" "Lab Failed: Developer cannot list deployments in production."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Developer has read-only access to production."
}

function test_cicd_serviceaccount_permissions() {
    if ! kubectl get serviceaccount cicd-deployer -n "$NAMESPACE_PROD" &>/dev/null; then
        print_status "failed" "Lab Failed: ServiceAccount 'cicd-deployer' does not exist in namespace '$NAMESPACE_PROD'."
        exit 1
    fi
    
    local can_create_deploy
    can_create_deploy=$(kubectl auth can-i create deployments --namespace="$NAMESPACE_PROD" --as="$CICD_SA" 2>/dev/null)
    
    if [ "$can_create_deploy" != "yes" ]; then
        print_status "failed" "Lab Failed: CI/CD ServiceAccount cannot create deployments in production."
        exit 1
    fi
    
    local can_update_deploy
    can_update_deploy=$(kubectl auth can-i update deployments --namespace="$NAMESPACE_PROD" --as="$CICD_SA" 2>/dev/null)
    
    if [ "$can_update_deploy" != "yes" ]; then
        print_status "failed" "Lab Failed: CI/CD ServiceAccount cannot update deployments in production."
        exit 1
    fi
    
    local can_delete_deploy
    can_delete_deploy=$(kubectl auth can-i delete deployments --namespace="$NAMESPACE_PROD" --as="$CICD_SA" 2>/dev/null)
    
    if [ "$can_delete_deploy" == "yes" ]; then
        print_status "failed" "Lab Failed: CI/CD ServiceAccount can delete deployments (should not have delete permission)."
        exit 1
    fi
    
    local can_delete_statefulsets
    can_delete_statefulsets=$(kubectl auth can-i delete statefulsets --namespace="$NAMESPACE_PROD" --as="$CICD_SA" 2>/dev/null)
    
    if [ "$can_delete_statefulsets" == "yes" ]; then
        print_status "failed" "Lab Failed: CI/CD ServiceAccount can delete statefulsets (should not have delete permission)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: CI/CD ServiceAccount has correct permissions (deploy but not delete)."
}

test_developer_can_view_prod
test_cicd_serviceaccount_permissions

print_status "success" "Lab Passed: All RBAC tests completed successfully. Security properly configured!"
exit 0
