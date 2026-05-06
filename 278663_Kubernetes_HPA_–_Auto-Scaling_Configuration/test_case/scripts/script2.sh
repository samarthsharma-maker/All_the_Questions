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

test_hpa_min_replicas
test_hpa_max_replicas

exit 0
