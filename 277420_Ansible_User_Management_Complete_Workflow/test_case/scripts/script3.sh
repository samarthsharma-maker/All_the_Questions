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

function user_existence_check() {
    for user in dev1 dev2 admin; do
        if ! ansible "$HOST_GROUP" -i "$TARGET_INVENTORY" -m command -a "id $user" &>/dev/null; then
            print_status "failed" "Lab Failed: User '$user' does not exist."
            exit 1
        fi
    done
    print_status "success" "Lab Passed: All required users exist."
}

function user_shell_check() {
    if ! ansible "$HOST_GROUP" -i "$TARGET_INVENTORY" -m shell -a "getent passwd dev1 dev2 admin | grep -q '/bin/bash'" &>/dev/null; then
        print_status "failed" "Lab Failed: One or more users do not have /bin/bash shell."
        exit 1
    fi
    print_status "success" "Lab Passed: All users have /bin/bash shell."
}

user_existence_check
user_shell_check
exit 0