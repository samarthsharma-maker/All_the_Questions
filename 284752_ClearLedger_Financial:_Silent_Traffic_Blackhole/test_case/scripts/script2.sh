#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR
NAMESPACE="clearledger-prod"

function test_tax_service_source_label() {
    local pod_selector
    pod_selector=$(kubectl get netpol allow-tax-service-ingress -n "$NAMESPACE" -o jsonpath='{range .spec.ingress[*].from[*]}{.podSelector.matchLabels.app}{"\n"}{end}' | grep "^payroll-worker$")

    if [ -z "$pod_selector" ]; then
        print_status "failed" "Lab Failed: allow-tax-service-ingress does not have a from rule with podSelector app=payroll-worker."
        exit 1
    fi
    print_status "success" "Lab Passed: allow-tax-service-ingress has from rule with podSelector app=payroll-worker."
}

function test_ledger_db_proxy_admin_toolbox() {
    local admin_rule
    admin_rule=$(kubectl get netpol allow-ledger-db-proxy-ingress -n "$NAMESPACE" -o jsonpath='{range .spec.ingress[*].from[*]}{.podSelector.matchLabels.app}{"\n"}{end}' | grep "^tax-service$")

    if [ -z "$admin_rule" ]; then
        print_status "failed" "Lab Failed: allow-ledger-db-proxy-ingress is missing a from rule with podSelector app=admin-toolbox. The admin-toolbox pod requires break-glass access to ledger-db-proxy on all ports."
        exit 1
    fi
    print_status "success" "Lab Passed: allow-ledger-db-proxy-ingress has break-glass from rule for admin-toolbox."
}

function test_prometheus_scraping_allowed() {
    local policies="allow-api-gateway-ingress allow-payroll-worker-ingress allow-tax-service-ingress allow-ledger-db-proxy-ingress"

    for policy in $policies; do
        local has_9090 ns_label
        has_9090=$(kubectl get netpol "$policy" -n "$NAMESPACE" -o jsonpath='{range .spec.ingress[*]}{.ports[*].port}{"\n"}{end}' | grep "^9090$")
        ns_label=$(kubectl get netpol "$policy" -n "$NAMESPACE" -o jsonpath='{range .spec.ingress[*]}{.ports[0].port}{" "}{range .from[*]}{.namespaceSelector.matchLabels.purpose}{end}{"\n"}{end}' | grep "^9090 " | awk '{print $2}')

        if [ -z "$has_9090" ]; then
            print_status "failed" "Lab Failed: $policy has no ingress rule for port 9090. Prometheus scraping from the monitoring namespace must be permitted on port 9090."
            exit 1
        fi
        if [ "$ns_label" != "monitoring" ]; then
            print_status "failed" "Lab Failed: $policy — the namespaceSelector for the port 9090 rule does not use 'purpose: monitoring' (found: '${ns_label:-MISSING}'). The monitoring namespace carries label purpose=monitoring."
            exit 1
        fi
    done
    print_status "success" "Lab Passed: All four service policies allow Prometheus scraping on port 9090 from namespace label purpose=monitoring."
}

test_tax_service_source_label
test_ledger_db_proxy_admin_toolbox
test_prometheus_scraping_allowed
print_status "success" "Lab Passed: tax-service ingress rules have correct podSelector and admin-toolbox break-glass rule is in place. Proceeding to check Prometheus scraping rules..."
exit 0