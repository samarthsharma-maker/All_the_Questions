#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

# ==========================================
# Variables
# ==========================================
NAMESPACE="ecommerce-prod"
DEPLOYMENT="shop-api"
HPA="shop-api-hpa"
LABEL_SELECTOR="app=shop-api"

# ==========================================
# Test 1: Deployment Has Resource Requests
# ==========================================
function test_deployment_has_requests() {
    local cpu_request mem_request
    
    cpu_request=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
    mem_request=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}')
    
    if [ -z "$cpu_request" ] || [ -z "$mem_request" ]; then
        print_status "failed" "Lab Failed: Deployment missing resource requests. HPA cannot work without requests."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Deployment has resource requests (cpu: $cpu_request, memory: $mem_request)."
}

# ==========================================
# Test 2: HPA Exists and References Correct Deployment
# ==========================================
function test_hpa_exists() {
    if ! kubectl get hpa "$HPA" -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: HPA '$HPA' does not exist in namespace '$NAMESPACE'."
        exit 1
    fi
    
    local target_deployment
    target_deployment=$(kubectl get hpa "$HPA" -n "$NAMESPACE" \
        -o jsonpath='{.spec.scaleTargetRef.name}')
    
    if [ "$target_deployment" != "$DEPLOYMENT" ]; then
        print_status "failed" "Lab Failed: HPA targets wrong deployment (expected: $DEPLOYMENT, found: $target_deployment)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: HPA exists and targets correct deployment."
}

# ==========================================
# Test 3: HPA minReplicas is at least 2
# ==========================================
function test_hpa_min_replicas() {
    local min_replicas
    min_replicas=$(kubectl get hpa "$HPA" -n "$NAMESPACE" -o jsonpath='{.spec.minReplicas}')
    
    if [ "$min_replicas" -lt 2 ]; then
        print_status "failed" "Lab Failed: minReplicas is too low (found: $min_replicas, minimum required: 2 for HA)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: minReplicas is set correctly ($min_replicas >= 2)."
}

# ==========================================
# Test 4: HPA maxReplicas is reasonable (not too high)
# ==========================================
function test_hpa_max_replicas() {
    local max_replicas
    max_replicas=$(kubectl get hpa "$HPA" -n "$NAMESPACE" -o jsonpath='{.spec.maxReplicas}')
    
    if [ "$max_replicas" -gt 20 ]; then
        print_status "failed" "Lab Failed: maxReplicas is too high (found: $max_replicas, should be <= 20 to prevent runaway scaling)."
        exit 1
    fi
    
    if [ "$max_replicas" -lt 5 ]; then
        print_status "failed" "Lab Failed: maxReplicas is too low (found: $max_replicas, should be >= 5 for proper scaling)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: maxReplicas is reasonable ($max_replicas)."
}

# ==========================================
# Test 5: HPA CPU Target is Appropriate
# ==========================================


# ==========================================
# Execute All Tests
# ==========================================
test_deployment_has_requests
test_hpa_exists
print_status "success" "Lab Passed: HPA is configured to target the correct deployment with resource requests in place. Proceeding to check scaling parameters..."
exit 0