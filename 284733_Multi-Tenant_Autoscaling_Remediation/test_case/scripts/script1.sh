#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="finflow-prod"
DEPLOYMENT="payment-processor"
HPA="payment-processor-hpa"
VPA="payment-processor-vpa"

function test_processor_has_requests() {
    local cpu_req mem_req
    cpu_req=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{" "}{.resources.requests.cpu}{"\n"}{end}' | grep "^processor " | awk '{print $2}')
    mem_req=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{" "}{.resources.requests.memory}{"\n"}{end}' | grep "^processor " | awk '{print $2}')

    if [ -z "$cpu_req" ] || [ -z "$mem_req" ]; then
        print_status "failed" "Lab Failed: 'processor' container is missing resource requests (cpu: '${cpu_req:-MISSING}', memory: '${mem_req:-MISSING}'). HPA cannot calculate utilization without requests — metrics will show <unknown>."
        exit 1
    fi

    print_status "success" "Lab Passed: 'processor' container has resource requests (cpu: $cpu_req, memory: $mem_req)."
}

function test_sidecar_has_requests() {
    local cpu_req mem_req
    cpu_req=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{" "}{.resources.requests.cpu}{"\n"}{end}' | grep "^audit-logger " | awk '{print $2}')
    mem_req=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{" "}{.resources.requests.memory}{"\n"}{end}' | grep "^audit-logger " | awk '{print $2}')

    if [ -z "$cpu_req" ] || [ -z "$mem_req" ]; then
        print_status "failed" "Lab Failed: 'audit-logger' sidecar is missing resource requests (cpu: '${cpu_req:-MISSING}', memory: '${mem_req:-MISSING}'). HPA sums requests across ALL containers — a missing sidecar request silently corrupts utilization calculations."
        exit 1
    fi

    print_status "success" "Lab Passed: 'audit-logger' sidecar has resource requests (cpu: $cpu_req, memory: $mem_req)."
}

function test_hpa_exists_and_targets_deployment() {
    if ! kubectl get hpa "$HPA" -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: HPA '$HPA' does not exist in namespace '$NAMESPACE'."
        exit 1
    fi

    local target
    target=$(kubectl get hpa "$HPA" -n "$NAMESPACE" -o jsonpath='{.spec.scaleTargetRef.name}')

    if [ "$target" != "$DEPLOYMENT" ]; then
        print_status "failed" "Lab Failed: HPA scaleTargetRef.name is '$target' — expected '$DEPLOYMENT'."
        exit 1
    fi

    print_status "success" "Lab Passed: HPA '$HPA' exists and targets deployment '$DEPLOYMENT'."
}


test_processor_has_requests
test_sidecar_has_requests
test_hpa_exists_and_targets_deployment
print_status "success" "Lab Passed: HPA is configured to target the correct deployment with resource requests in place. Proceeding to check scaling parameters..."
exit 0
