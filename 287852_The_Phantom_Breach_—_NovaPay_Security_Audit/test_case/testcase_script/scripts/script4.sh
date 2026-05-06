#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

BASE_DIR="/home/user"
ZOMBIE_SCRIPT="${BASE_DIR}/zombie_audit.sh"
FIREWALL_SCRIPT="${BASE_DIR}/firewall_audit.sh"
ZOMBIE_REPORT="${BASE_DIR}/zombie_report.txt"
FIREWALL_REPORT="${BASE_DIR}/firewall_report.txt"

spawn_zombie() {
    if [[ -f /tmp/zombie_parent_pid.txt ]]; then
        OLD_PID=$(cat /tmp/zombie_parent_pid.txt)
        kill "$OLD_PID" 2>/dev/null || true
        sleep 1
    fi
    /tmp/make_zombie &
    echo $! > /tmp/zombie_parent_pid.txt
    sleep 1
}

apply_firewall_rules() {
    iptables -F INPUT   2>/dev/null || true
    iptables -F FORWARD 2>/dev/null || true
    iptables -A INPUT   -j ACCEPT
    iptables -A FORWARD -j ACCEPT
    iptables -A INPUT   -s 192.168.1.100 -j DROP
}

Test2b() {
    iptables -F INPUT   2>/dev/null || true
    iptables -F FORWARD 2>/dev/null || true

    bash "$FIREWALL_SCRIPT"

    if ! grep -q "^\[FIREWALL AUDIT\]" "$FIREWALL_REPORT"; then
        print_status "failed" "Missing [FIREWALL AUDIT] header after rules were flushed"
        apply_firewall_rules
        exit 1
    fi

    if grep -qE "^CHAIN:(INPUT|FORWARD)" "$FIREWALL_REPORT"; then
        print_status "failed" "Chain entries still present after iptables was flushed — values may be hardcoded"
        apply_firewall_rules
        exit 1
    fi

    if ! grep -q "^NONE$" "$FIREWALL_REPORT"; then
        print_status "failed" "Report should say NONE after iptables was flushed — values may be hardcoded"
        apply_firewall_rules
        exit 1
    fi

    apply_firewall_rules
    print_status "success" "Firewall report correctly updates to NONE after rules flushed"
}

Test2b 
print_status "success" "Lab Passed: Script correctly identifies permissive firewall rules and updates report when rules are flushed."
exit 0