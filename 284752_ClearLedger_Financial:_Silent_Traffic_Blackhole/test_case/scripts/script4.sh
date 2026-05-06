#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR
NAMESPACE="clearledger-prod"

function test_payroll_worker_no_wrong_monitoring_label() {
    local wrong_label
    wrong_label=$(kubectl get netpol allow-payroll-worker-ingress -n "$NAMESPACE" -o jsonpath='{range .spec.ingress[*].from[*]}{.namespaceSelector.matchLabels.team}{"\n"}{end}' | grep "^monitoring$")

    if [ -n "$wrong_label" ]; then
        print_status "failed" "Lab Failed: allow-payroll-worker-ingress uses namespaceSelector 'team: monitoring' which does not exist on the monitoring namespace. The correct label is 'purpose: monitoring'. Prometheus scraping will silently fail until this is fixed."
        exit 1
    fi
    print_status "success" "Lab Passed: allow-payroll-worker-ingress does not use the non-existent 'team: monitoring' label."
}

function test_all_policies_have_admin_toolbox() {
    local policies="allow-api-gateway-ingress allow-payroll-worker-ingress allow-tax-service-ingress allow-ledger-db-proxy-ingress"

    for policy in $policies; do
        local admin_rule
        admin_rule=$(kubectl get netpol "$policy" -n "$NAMESPACE" -o jsonpath='{range .spec.ingress[*].from[*]}{.podSelector.matchLabels.app}{"\n"}{end}' | grep "^admin-toolbox$")
        if [ -z "$admin_rule" ]; then
            print_status "failed" "Lab Failed: $policy is missing a from rule with podSelector app=admin-toolbox. The SRE admin-toolbox pod requires break-glass access to all services."
            exit 1
        fi
    done
    print_status "success" "Lab Passed: All four service policies include the admin-toolbox break-glass ingress rule."
}

test_payroll_worker_no_wrong_monitoring_label
test_all_policies_have_admin_toolbox
print_status "success" "Lab Passed: payroll-worker ingress rules have correct monitoring label and all policies have admin-toolbox break-glass rule. Proceeding to check tax-service ingress rules..."
exit 0
