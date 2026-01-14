#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

# ==========================
# VARIABLES
# ==========================
WORKDIR="/home/user/workspace"
PLAYBOOK_NAME="user-management.yml"
TARGET_PLAYBOOK="${WORKDIR}/${PLAYBOOK_NAME}"
TARGET_INVENTORY="${WORKDIR}/inventory.ini"
HOST_GROUP="web"

function playbook_syntax_check() {
    if ! ansible-playbook -i "$TARGET_INVENTORY" "$TARGET_PLAYBOOK" --syntax-check &>/dev/null; then
        print_status "failed" "Lab Failed: Syntax errors found in '${PLAYBOOK_NAME}'."
        exit 1
    fi
    print_status "success" "Lab Passed: '${PLAYBOOK_NAME}' passed syntax check."
}

function playbook_execution_check() {
    if ! ansible-playbook -i "$TARGET_INVENTORY" "$TARGET_PLAYBOOK" &>/dev/null; then
        print_status "failed" "Lab Failed: Errors occurred during execution of '${PLAYBOOK_NAME}'."
        exit 1
    fi
    print_status "success" "Lab Passed: '${PLAYBOOK_NAME}' executed successfully."
}

playbook_syntax_check
playbook_execution_check
exit 0