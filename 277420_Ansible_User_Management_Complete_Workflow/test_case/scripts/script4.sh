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

function home_directory_check() {
    if ! ansible "$HOST_GROUP" -i "$TARGET_INVENTORY" \
        -m shell -a "test -d /home/dev1 && test -d /home/dev2 && test -d /home/admin" \
        &>/dev/null; then
        print_status "failed" "Lab Failed: One or more home directories are missing."
        exit 1
    fi

    print_status "success" "Lab Passed: All home directories exist."
}

function olduser_removal_check() {

    if ansible "$HOST_GROUP" -i "$TARGET_INVENTORY" \
        -m shell -a "id olduser" &>/dev/null; then
        print_status "failed" "Lab Failed: 'olduser' still exists."
        exit 1
    fi

    if ansible "$HOST_GROUP" -i "$TARGET_INVENTORY" \
        -m shell -a "test -d /home/olduser" &>/dev/null; then
        print_status "failed" "Lab Failed: '/home/olduser' still exists."
        exit 1
    fi

    print_status "success" "Lab Passed: 'olduser' removed completely."
}


home_directory_check
olduser_removal_check
exit 0