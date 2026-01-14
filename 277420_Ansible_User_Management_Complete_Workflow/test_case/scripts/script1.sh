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

# ==========================
# CHECKS
# ==========================

function workspace_check() {
    if [[ ! -d "$WORKDIR" ]]; then
        print_status "failed" "Lab Failed: Workspace directory '${WORKDIR}' does not exist."
        exit 1
    fi
    print_status "success" "Lab Passed: Workspace directory exists."
}

function inventory_check() {
    if [[ ! -f "$TARGET_INVENTORY" ]]; then
        print_status "failed" "Lab Failed: inventory.ini not found in workspace."
        exit 1
    fi

    if ! ansible-inventory -i "$TARGET_INVENTORY" --list &>/dev/null; then
        print_status "failed" "Lab Failed: inventory.ini is invalid or unparsable."
        exit 1
    fi

    print_status "success" "Lab Passed: inventory.ini exists and is valid."
}

function playbook_existence_check() {
    if [[ ! -f "$TARGET_PLAYBOOK" ]]; then
        print_status "failed" "Lab Failed: '${PLAYBOOK_NAME}' not found in workspace."
        exit 1
    fi
    print_status "success" "Lab Passed: '${PLAYBOOK_NAME}' found."
}

workspace_check
inventory_check
playbook_existence_check
exit 0
