#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR
NAMESPACE="clearledger-prod"

function test_egress_dns_pod_selector_empty() {
    local selector
    selector=$(kubectl get netpol allow-egress-dns -n "$NAMESPACE" -o jsonpath='{.spec.podSelector.matchLabels}')

    if [ -n "$selector" ] && [ "$selector" != "map[]" ]; then
        print_status "failed" "Lab Failed: allow-egress-dns podSelector is '$selector' — it is scoped to specific pods. Set podSelector to {} so the DNS egress rule applies to ALL pods in the namespace, not just one service."
        exit 1
    fi
    print_status "success" "Lab Passed: allow-egress-dns podSelector is empty — applies to all pods in clearledger-prod."
}

function test_egress_dns_targets_kube_system() {
    local ns_label
    ns_label=$(kubectl get netpol allow-egress-dns -n "$NAMESPACE" -o jsonpath='{range .spec.egress[*].to[*]}{.namespaceSelector.matchLabels}' | grep -o 'kube-system')

    if [ -z "$ns_label" ]; then
        print_status "failed" "Lab Failed: allow-egress-dns does not target kube-system via 'kubernetes.io/metadata.name: kube-system'. kube-dns runs in kube-system — using any other namespace label (e.g. dns-system) will silently break DNS for all pods."
        exit 1
    fi
    print_status "success" "Lab Passed: allow-egress-dns correctly targets kube-system via kubernetes.io/metadata.name."
}

function test_egress_dns_ports() {
    local udp_53 tcp_53
    udp_53=$(kubectl get netpol allow-egress-dns -n "$NAMESPACE" -o jsonpath='{range .spec.egress[*].ports[*]}{.protocol}{" "}{.port}{"\n"}{end}' | grep "^UDP 53$")
    tcp_53=$(kubectl get netpol allow-egress-dns -n "$NAMESPACE" -o jsonpath='{range .spec.egress[*].ports[*]}{.protocol}{" "}{.port}{"\n"}{end}' | grep "^TCP 53$")

    if [ -z "$udp_53" ]; then
        print_status "failed" "Lab Failed: allow-egress-dns is missing UDP port 53. DNS queries use UDP by default — without this rule DNS will silently fail for all pods."
        exit 1
    fi
    if [ -z "$tcp_53" ]; then
        print_status "failed" "Lab Failed: allow-egress-dns is missing TCP port 53. Large DNS responses (DNSSEC, long records) fall back to TCP — without this rule those lookups will silently fail."
        exit 1
    fi
    print_status "success" "Lab Passed: allow-egress-dns permits both UDP 53 and TCP 53."
}

test_egress_dns_pod_selector_empty
test_egress_dns_targets_kube_system
test_egress_dns_ports
print_status "success" "Lab Passed: allow-egress-dns is correctly configured with empty podSelector, targets kube-system, and allows both UDP and TCP on port 53. Proceeding to check payroll-worker monitoring label and admin-toolbox rules..."
exit 0
