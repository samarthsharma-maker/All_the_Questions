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


Test2a() {
    bash "$FIREWALL_SCRIPT"

    if [[ ! -f "$FIREWALL_REPORT" ]]; then
        print_status "failed" "firewall_report.txt was not created"
        exit 1
    fi

    if ! grep -q "^\[FIREWALL AUDIT\]" "$FIREWALL_REPORT"; then
        print_status "failed" "Missing [FIREWALL AUDIT] header in firewall_report.txt"
        exit 1
    fi

    if grep -q "^NONE$" "$FIREWALL_REPORT"; then
        print_status "failed" "Report says NONE but permissive rules were planted by setup"
        exit 1
    fi

    if ! grep -qE "^CHAIN:INPUT RULE:ACCEPT.+0\.0\.0\.0/0" "$FIREWALL_REPORT"; then
        print_status "failed" "Permissive INPUT ACCEPT rule not found in firewall_report.txt"
        exit 1
    fi

    if ! grep -qE "^CHAIN:FORWARD RULE:ACCEPT.+0\.0\.0\.0/0" "$FIREWALL_REPORT"; then
        print_status "failed" "Permissive FORWARD ACCEPT rule not found in firewall_report.txt"
        exit 1
    fi

    if grep -q "192\.168\.1\.100" "$FIREWALL_REPORT"; then
        print_status "failed" "Restrictive DROP rule for 192.168.1.100 was incorrectly flagged"
        exit 1
    fi

    print_status "success" "Firewall rules correctly detected"
}


Test2a
print_status "success" "Lab Passed: Script correctly identifies permissive firewall rules and ignores restrictive rules."
exit 0
