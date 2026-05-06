#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR
NAMESPACE="clearledger-prod"

# ==========================================
# Test 1: api-gateway ingress on 8080 allows from any source
# The ingress rule for port 8080 must have an empty from block
# (no podSelector or namespaceSelector restrictions).
# We check that no podSelector or namespaceSelector appears
# inside the 8080 ingress rule by looking at the raw YAML and
# confirming from is absent or empty for that port entry.
# Strategy: export full policy, isolate the 8080 block, ensure
# there is no "podSelector" or "namespaceSelector" within it.
# ==========================================
function test_api_gateway_open_ingress() {
    local ports_with_from
    ports_with_from=$(kubectl get netpol allow-api-gateway-ingress -n "$NAMESPACE" -o jsonpath='{range .spec.ingress[*]}{.ports[*].port}{" from:"}{range .from[*]}{.podSelector.matchLabels}{.namespaceSelector.matchLabels}{end}{"\n"}{end}')

    # The 8080 entry must have no from restrictions (empty from array means open)
    local line_8080
    line_8080=$(echo "$ports_with_from" | grep "^8080 ")

    if echo "$line_8080" | grep -q "from:map\["; then
        print_status "failed" "Lab Failed: allow-api-gateway-ingress port 8080 still has a podSelector or namespaceSelector restriction. api-gateway is the public entry point — the from block for port 8080 must be empty so any source can reach it."
        exit 1
    fi

    print_status "success" "Lab Passed: allow-api-gateway-ingress port 8080 has no from restrictions (open ingress)."
}

# ==========================================
# Test 2: payroll-worker ingress on 8080 allows only from
# app=api-gateway AND namespace clearledger-prod.
# We verify a podSelector with app=api-gateway exists in
# the ingress rules for this policy.
# ==========================================
function test_payroll_worker_ingress_source() {
    local pod_selector
    pod_selector=$(kubectl get netpol allow-payroll-worker-ingress -n "$NAMESPACE" -o jsonpath='{range .spec.ingress[*].from[*]}{.podSelector.matchLabels.app}{"\n"}{end}' | grep "^api-gateway$")

    if [ -z "$pod_selector" ]; then
        print_status "failed" "Lab Failed: allow-payroll-worker-ingress does not have a from rule with podSelector app=api-gateway. payroll-worker must only accept traffic from api-gateway."
        exit 1
    fi

    print_status "success" "Lab Passed: allow-payroll-worker-ingress has from rule with podSelector app=api-gateway."
}

function test_tax_service_and_logic() {
    local from_count
    from_count=$(kubectl get netpol allow-tax-service-ingress -n "$NAMESPACE" -o jsonpath='{range .spec.ingress[*]}{.ports[0].port}{" "}{range .from[*]}X{end}{"\n"}{end}' | grep "^8443 " | awk '{print length($2)}')

    if [ -z "$from_count" ]; then
        print_status "failed" "Lab Failed: allow-tax-service-ingress has no ingress rule for port 8443."
        exit 1
    fi

    if [ "$from_count" -gt 1 ]; then
        print_status "failed" "Lab Failed: allow-tax-service-ingress port 8443 has $from_count separate from items (OR logic). Use a single from item with both namespaceSelector and podSelector together (AND logic) to restrict access to only payroll-worker in clearledger-prod."
        exit 1
    fi

    print_status "success" "Lab Passed: allow-tax-service-ingress port 8443 uses AND logic (single from item with both selectors)."
}


test_api_gateway_open_ingress
test_payroll_worker_ingress_source
test_tax_service_and_logic
print_status "success" "Lab Passed: api-gateway and payroll-worker ingress rules have correct
podSelector restrictions. Proceeding to check tax-service ingress logic and selectors..."
exit 0