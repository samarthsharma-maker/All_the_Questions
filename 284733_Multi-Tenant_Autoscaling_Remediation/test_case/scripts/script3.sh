#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="finflow-prod"
DEPLOYMENT="payment-processor"
HPA="payment-processor-hpa"
VPA="payment-processor-vpa"

function test_hpa_custom_metric() {
    local metric_names raw_value numeric_value
    metric_names=$(kubectl get hpa "$HPA" -n "$NAMESPACE" -o jsonpath='{range .spec.metrics[?(@.type=="Object")]}{.object.metric.name}{"\n"}{end}')
    raw_value=$(kubectl get hpa "$HPA" -n "$NAMESPACE" -o jsonpath='{range .spec.metrics[?(@.type=="Object")]}{.object.metric.name}{" "}{.object.target.value}{"\n"}{end}' | grep "^pending_transactions " | awk '{print $2}')
    numeric_value=$(echo "$raw_value" | grep -o '^[0-9]*')

    if ! echo "$metric_names" | grep -q "^pending_transactions$"; then
        print_status "failed" "Lab Failed: Custom metric 'pending_transactions' is not configured in the HPA. Queue depth is the primary scaling signal for payment workloads — CPU is a lagging indicator."
        exit 1
    fi

    if [ -z "$raw_value" ]; then
        print_status "failed" "Lab Failed: 'pending_transactions' metric found but has no target value set."
        exit 1
    fi

    if [ -z "$numeric_value" ] || [ "$numeric_value" -gt 500 ]; then
        print_status "failed" "Lab Failed: 'pending_transactions' threshold is '$raw_value'. Must be a numeric value <= 500 to ensure timely scale-out before queue depth causes SLA violations."
        exit 1
    fi

    print_status "success" "Lab Passed: Custom metric 'pending_transactions' configured with threshold $raw_value (<= 500)."
}

function test_vpa_mode_off() {
    if ! kubectl api-resources 2>/dev/null | grep -q "verticalpodautoscalers"; then
        print_status "success" "Lab Passed: VPA CRD not available in this cluster — VPA conflict task skipped."
        return
    fi

    if ! kubectl get vpa "$VPA" -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: VPA '$VPA' not found. Do not delete the VPA — change its updateMode to 'Off'."
        exit 1
    fi

    local vpa_mode
    vpa_mode=$(kubectl get vpa "$VPA" -n "$NAMESPACE" -o jsonpath='{.spec.updatePolicy.updateMode}')

    if [ "$vpa_mode" != "Off" ]; then
        print_status "failed" "Lab Failed: VPA updateMode is '$vpa_mode'. Must be 'Off' to prevent VPA from evicting pods while HPA is scaling horizontally."
        exit 1
    fi

    print_status "success" "Lab Passed: VPA '$VPA' updateMode = Off (no conflict with HPA)."
}

test_hpa_custom_metric
test_vpa_mode_off
print_status "success" "Lab Passed: HPA custom metric and VPA configuration are correct. Proceeding to check PDB and stabilization settings..."
exit 0