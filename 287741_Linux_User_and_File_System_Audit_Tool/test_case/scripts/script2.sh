#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

BASE_DIR="/home/user"
SCRIPT="${BASE_DIR}/sys_audit.sh"
REPORT="${BASE_DIR}/audit_report.txt"

Test2() {
    bash "$SCRIPT"

    if ! grep -q "^\[SUDO AUDIT\]" "$REPORT"; then
        print_status "failed" "Missing [SUDO AUDIT] section header"
        exit 1
    fi

    if ! grep -q "^alice  SUDO:YES" "$REPORT"; then
        print_status "failed" "alice should have SUDO:YES"
        exit 1
    fi

    if ! grep -q "^bob  SUDO:NO" "$REPORT"; then
        print_status "failed" "bob should have SUDO:NO"
        exit 1
    fi

    if ! grep -q "^charlie  SUDO:YES" "$REPORT"; then
        print_status "failed" "charlie should have SUDO:YES"
        exit 1
    fi

    print_status "success" "Sudo audit section is correct"
}

Test2
print_status "success" "Lab Passed: Sudo audit section is correct in the report."
exit 0