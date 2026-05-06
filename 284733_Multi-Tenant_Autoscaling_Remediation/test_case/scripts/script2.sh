#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="finflow-prod"
DEPLOYMENT="payment-processor"
HPA="payment-processor-hpa"
VPA="payment-processor-vpa"

function test_hpa_min_replicas() {
    local min_replicas
    min_replicas=$(kubectl get hpa "$HPA" -n "$NAMESPACE"  -o jsonpath='{.spec.minReplicas}')

    if [ -z "$min_replicas" ]; then
        print_status "failed" "Lab Failed: HPA minReplicas is not set."
        exit 1
    fi

    if [ "$min_replicas" -lt 3 ]; then
        print_status "failed" "Lab Failed: HPA minReplicas is $min_replicas. Payment processing requires at least 3 replicas for high availability."
        exit 1
    fi

    print_status "success" "Lab Passed: HPA minReplicas = $min_replicas (>= 3)."
}

function test_hpa_max_replicas() {
    local max_replicas
    max_replicas=$(kubectl get hpa "$HPA" -n "$NAMESPACE" -o jsonpath='{.spec.maxReplicas}')

    if [ -z "$max_replicas" ]; then
        print_status "failed" "Lab Failed: HPA maxReplicas is not set."
        exit 1
    fi

    if [ "$max_replicas" -lt 8 ]; then
        print_status "failed" "Lab Failed: HPA maxReplicas is $max_replicas — too low. Must be >= 8 to handle payment traffic spikes."
        exit 1
    fi

    if [ "$max_replicas" -gt 25 ]; then
        print_status "failed" "Lab Failed: HPA maxReplicas is $max_replicas — too high. Must be <= 25 to prevent runaway scaling."
        exit 1
    fi

    print_status "success" "Lab Passed: HPA maxReplicas = $max_replicas (8–25 range)."
}

function test_hpa_cpu_target() {
    local cpu_target
    cpu_target=$(kubectl get hpa "$HPA" -n "$NAMESPACE" -o jsonpath='{.spec.metrics[?(@.resource.name=="cpu")].resource.target.averageUtilization}')

    if [ -z "$cpu_target" ]; then
        print_status "failed" "Lab Failed: HPA has no CPU resource metric configured."
        exit 1
    fi

    if [ "$cpu_target" -lt 60 ]; then
        print_status "failed" "Lab Failed: CPU averageUtilization is ${cpu_target}% — too low (< 60%). Causes over-aggressive scaling and resource waste."
        exit 1
    fi

    if [ "$cpu_target" -gt 85 ]; then
        print_status "failed" "Lab Failed: CPU averageUtilization is ${cpu_target}% — too high (> 85%). Pods saturate before HPA can react."
        exit 1
    fi

    print_status "success" "Lab Passed: HPA CPU averageUtilization = ${cpu_target}% (60–85% range)."
}

function test_hpa_memory_metric() {
    local mem_target
    mem_target=$(kubectl get hpa "$HPA" -n "$NAMESPACE" -o jsonpath='{.spec.metrics[?(@.resource.name=="memory")].resource.target.averageUtilization}')

    if [ -z "$mem_target" ]; then
        print_status "failed" "Lab Failed: Memory metric is missing from HPA. The payment processor is memory-intensive — CPU alone is insufficient."
        exit 1
    fi

    if [ "$mem_target" -lt 70 ]; then
        print_status "failed" "Lab Failed: Memory averageUtilization is ${mem_target}% — too low (< 70%). Causes unnecessary scale-out."
        exit 1
    fi

    if [ "$mem_target" -gt 90 ]; then
        print_status "failed" "Lab Failed: Memory averageUtilization is ${mem_target}% — too high (> 90%). Pods may OOM before HPA scales out."
        exit 1
    fi

    print_status "success" "Lab Passed: HPA memory averageUtilization = ${mem_target}% (70–90% range)."
}

test_hpa_min_replicas
test_hpa_max_replicas
test_hpa_cpu_target
test_hpa_memory_metric
print_status "success" "Lab Passed: HPA scaling parameters (minReplicas, maxReplicas, CPU and memory targets) are all configured within recommended ranges."
exit 0
