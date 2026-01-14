#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"
PLAYBOOK_NAME="broken-playbook.yml"
TARGET_PLAYBOOK="${TARGET_DIR}/${PLAYBOOK_NAME}"
TARGET_INVENTORY="${TARGET_DIR}/workspace/inventory.ini"

function workspace_directory_check() {
    if [[ ! -d "${TARGET_DIR}/workspace" ]]; then
        print_status "failed" "Lab Failed: 'workspace' directory not found in ${TARGET_DIR}."
        exit 1
    fi
    if [[ ! -f "${TARGET_INVENTORY}" ]]; then
        print_status "failed" "Lab Failed: 'inventory.ini' file not found in workspace directory."
        exit 1
    fi
    print_status "success" "Lab Passed: 'workspace' directory and 'inventory.ini' file found."
}

function inventory_file_check() {
    if ! grep -q "\[web\]" "${TARGET_INVENTORY}"; then
        print_status "failed" "Lab Failed: '[web]' group not found in inventory.ini."
        exit 1
    fi
    if ! grep -q "server1 ansible_host=server1" "${TARGET_INVENTORY}"; then
        print_status "failed" "Lab Failed: 'server1' host entry not found or incorrect in inventory.ini."
        exit 1
    fi
    print_status "success" "Lab Passed: Inventory file contains correct group and host entries."
}

function inventory_configuration_check() {
    if ! grep -q "ansible_user=server1_admin" "${TARGET_INVENTORY}"; then
        print_status "failed" "Lab Failed: 'ansible_user' not correctly set for server1 in inventory.ini."
        exit 1
    fi
    if ! grep -q "ansible_password=server1_admin@123!" "${TARGET_INVENTORY}"; then
        print_status "failed" "Lab Failed: 'ansible_password' not correctly set for server1 in inventory.ini."
        exit 1
    fi
    if ! grep -q "ansible_become_password=server1_admin@123!" "${TARGET_INVENTORY}"; then
        print_status "failed" "Lab Failed: 'ansible_become_password' not correctly set for server1 in inventory.ini."
        exit 1
    fi
    print_status "success" "Lab Passed: Inventory file has correct authentication details."
}


workspace_directory_check
inventory_file_check
inventory_configuration_check
exit 0