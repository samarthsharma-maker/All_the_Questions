#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"
WORKSPACE="${TARGET_DIR}/workspace"
INVENTORY="${WORKSPACE}/inventory.ini"
PLAYBOOK="${WORKSPACE}/file-operations.yml"

function directory_check() {
    local path="$1"
    local expected_mode="$2"

    RESULT=$(ansible -i "$INVENTORY" web -m stat -a "path=${path}" --one-line 2>/dev/null)

    echo "$RESULT" | grep -q '"exists": true' || {
        print_status "failed" "Directory ${path} does not exist."
        exit 1
    }

    ACTUAL_MODE=$(echo "$RESULT" | grep -o '"mode": "[0-9]*"' | cut -d'"' -f4)

    if [[ "$ACTUAL_MODE" == "$expected_mode" ]]; then
        print_status "success" "Directory ${path} exists with correct permissions (${expected_mode})."
    else
        print_status "failed" "Directory ${path} has incorrect permissions (expected ${expected_mode}, got ${ACTUAL_MODE})."
        exit 1
    fi
}

directory_check "/opt/app" "0755"
directory_check "/opt/app/logs" "0755"
directory_check "/opt/app/config" "0750"

print_status "success" "Lab Passed: All file module operations completed successfully."
exit 0