#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"
PLAYBOOK_NAME="broken-playbook.yml"
TARGET_PLAYBOOK="${TARGET_DIR}/${PLAYBOOK_NAME}"
TARGET_INVENTORY="${TARGET_DIR}/workspace/inventory.ini"

function playbook_existance_check() {
    if [[ ! -f "${TARGET_PLAYBOOK}" ]]; then
        print_status "failed" "Lab Failed: '${PLAYBOOK_NAME}' not found in ${TARGET_DIR}."
        exit 1
    fi
    print_status "success" "Lab Passed: '${PLAYBOOK_NAME}' found."
}

function playbook_syntax_check() {
    if ! ansible-playbook -i "${TARGET_INVENTORY}" "${TARGET_PLAYBOOK}" --syntax-check &>/dev/null; then
        print_status "failed" "Lab Failed: Syntax errors found in '${PLAYBOOK_NAME}'."
        exit 1
    fi
    print_status "success" "Lab Passed: '${PLAYBOOK_NAME}' passed syntax check."
}

function playbook_execution_check() {
    if ! ansible-playbook -i "${TARGET_INVENTORY}" "${TARGET_PLAYBOOK}" &>/dev/null; then
        print_status "failed" "Lab Failed: Errors occurred during execution of '${PLAYBOOK_NAME}'."
        exit 1
    fi
    print_status "success" "Lab Passed: '${PLAYBOOK_NAME}' executed successfully."
}

playbook_existance_check
playbook_syntax_check
playbook_execution_check
exit 0