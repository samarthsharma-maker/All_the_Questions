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


function test_hpa_cpu_target() {
    local cpu_target
    cpu_target=$(kubectl get hpa "$HPA" -n "$NAMESPACE" \
        -o jsonpath='{.spec.metrics[?(@.resource.name=="cpu")].resource.target.averageUtilization}')
    
    if [ -z "$cpu_target" ]; then
        print_status "failed" "Lab Failed: HPA has no CPU metric configured."
        exit 1
    fi
    
    if [ "$cpu_target" -lt 50 ]; then
        print_status "failed" "Lab Failed: CPU target too low (found: ${cpu_target}%, should be >= 50% for efficiency)."
        exit 1
    fi
    
    if [ "$cpu_target" -gt 90 ]; then
        print_status "failed" "Lab Failed: CPU target too high (found: ${cpu_target}%, should be <= 90% for responsiveness)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: CPU target is appropriate (${cpu_target}%)."
}

# ==========================================
# Test 6: HPA Has Memory Metric
# ==========================================
function test_hpa_has_memory_metric() {
    local memory_target
    memory_target=$(kubectl get hpa "$HPA" -n "$NAMESPACE" \
        -o jsonpath='{.spec.metrics[?(@.resource.name=="memory")].resource.target.averageUtilization}')
    
    if [ -z "$memory_target" ]; then
        print_status "failed" "Lab Failed: HPA does not have memory metric. Should monitor both CPU and memory."
        exit 1
    fi
    
    print_status "success" "Lab Passed: HPA monitors memory (target: ${memory_target}%)."
}

test_hpa_cpu_target
test_hpa_has_memory_metric

exit 0
