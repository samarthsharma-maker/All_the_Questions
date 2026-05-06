#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

BASE_DIR="/home/user"
SCRIPT="${BASE_DIR}/sys_audit.sh"
REPORT="${BASE_DIR}/audit_report.txt"

if [ ! -f "$SCRIPT" ]; then
    print_status "failed" "sys_audit.sh not found in /home/user/"
    exit 1
fi

Test1() {
    bash "$SCRIPT"

    if ! grep -q "^\[ORPHANED FILES\]" "$REPORT"; then
        print_status "failed" "Missing [ORPHANED FILES] section header"
        exit 1
    fi

    orphan_count=$(awk '/^\[ORPHANED FILES\]/{found=1; next} /^\[/{found=0} found && !/^NONE/' "$REPORT" | grep -c .)

    if [ "$orphan_count" -lt 3 ]; then
        print_status "failed" "Expected at least 3 orphaned entries under /home/user/audit_zone, got: $orphan_count"
        exit 1
    fi

    if ! grep -q "/home/user/audit_zone/" "$REPORT"; then
        print_status "failed" "Orphaned file paths should be under /home/user/audit_zone/"
        exit 1
    fi

    print_status "success" "Orphaned files section is correct"
}

Test1
print_status "success" "Lab Passed: Script correctly identifies orphaned files and generates the expected report."
exit 0