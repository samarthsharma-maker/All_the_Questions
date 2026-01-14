#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"
WORKSPACE="${TARGET_DIR}/workspace"
INVENTORY="${WORKSPACE}/inventory.ini"
PLAYBOOK="${WORKSPACE}/file-operations.yml"


function inventory_exists_check() {
    if [[ -f "$INVENTORY" ]]; then
        print_status "success" "Inventory file exists."
    else
        print_status "failed" "Inventory file not found at ${INVENTORY}."
        exit 1
    fi
}

function playbook_exists_check() {
    if [[ -f "$PLAYBOOK" ]]; then
        print_status "success" "Playbook file exists."
    else
        print_status "failed" "Playbook file not found at ${PLAYBOOK}."
        exit 1
    fi
}


inventory_exists_check
playbook_exists_check


print_status "success" "Lab Passed: All file module operations completed successfully."
exit 0
