#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

BASE_DIR="/home/user"
ZOMBIE_SCRIPT="${BASE_DIR}/zombie_audit.sh"
ZOMBIE_REPORT="${BASE_DIR}/zombie_report.txt"

if [[ ! -f "$ZOMBIE_SCRIPT" ]]; then
    print_status "failed" "zombie_audit.sh not found in /home/user/"
    exit 1
fi
chmod +x "$ZOMBIE_SCRIPT"

spawn_zombie

Test1a() {
    bash "$ZOMBIE_SCRIPT"

    if [[ ! -f "$ZOMBIE_REPORT" ]]; then
        print_status "failed" "zombie_report.txt was not created"
        exit 1
    fi

    if ! grep -q "^\[ZOMBIE PROCESSES\]" "$ZOMBIE_REPORT"; then
        print_status "failed" "Missing [ZOMBIE PROCESSES] header in zombie_report.txt"
        exit 1
    fi

    if grep -q "^NONE$" "$ZOMBIE_REPORT"; then
        print_status "failed" "Report says NONE but a zombie process was planted by setup"
        exit 1
    fi

    if ! grep -qE "^PID:[0-9]+ $" "$ZOMBIE_REPORT"; then
        print_status "failed" "Expected PID line in format 'PID:<number> ' -- zombie not detected"
        exit 1
    fi

    if ! grep -qE "^PARENT:make_zombie$" "$ZOMBIE_REPORT"; then
        print_status "failed" "Expected PARENT:make_zombie -- zombie not detected or parent name is wrong"
        exit 1
    fi

    print_status "success" "Zombie process correctly detected"
}

Test1a
print_status "success" "Lab Passed: Script correctly identifies zombie processes and their parent names."
exit 0