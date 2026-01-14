#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"
WORKSPACE="${TARGET_DIR}/workspace"
INVENTORY="${WORKSPACE}/inventory.ini"
PLAYBOOK="${WORKSPACE}/file-operations.yml"

function file_check() {
    local path="$1"
    local expected_mode="$2"

    RESULT=$(ansible -i "$INVENTORY" web --become -m stat -a "path=${path}")

    echo "$RESULT" | grep -q '"exists": true' || {
        print_status "failed" "File ${path} does not exist."
        exit 1
    }

    ACTUAL_MODE=$(echo "$RESULT" | grep -o '"mode": "[0-9]*"' | cut -d'"' -f4)

    if [[ "$ACTUAL_MODE" == "$expected_mode" ]]; then
        print_status "success" "File ${path} exists with correct permissions (${expected_mode})."
    else
        print_status "failed" "File ${path} has incorrect permissions (expected ${expected_mode}, got ${ACTUAL_MODE})."
        exit 1
    fi
}

function temp_file_absent_check() {
    if ansible -i "$INVENTORY" web -m stat -a "path=/tmp/old_file.txt" \
        | grep -q '"exists": false'; then
        print_status "success" "Temporary file /tmp/old_file.txt has been removed."
    else
        print_status "failed" "Temporary file /tmp/old_file.txt still exists."
        exit 1
    fi
}

file_check "/opt/app/config/app.conf" "0644"

temp_file_absent_check

print_status "success" "Lab Passed: All file module operations completed successfully."
exit 0