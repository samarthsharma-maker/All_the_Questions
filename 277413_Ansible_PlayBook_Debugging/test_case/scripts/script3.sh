#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"
PLAYBOOK_NAME="broken-playbook.yml"
TARGET_PLAYBOOK="${TARGET_DIR}/${PLAYBOOK_NAME}"
TARGET_INVENTORY="${TARGET_DIR}/workspace/inventory.ini"

function git_installation_check() {
    if ansible -i "$TARGET_INVENTORY" web -m shell -a "git --version" &>/dev/null; then
        print_status "success" "Lab Passed: 'git' is installed on server1."
    else
        print_status "failed" "Lab Failed: 'git' is not installed on server1."
        exit 1
    fi
}

function nginx_service_check() {
    if ansible -i "$TARGET_INVENTORY" web -m shell -a "systemctl is-active nginx" | grep -q "active"; then
        print_status "success" "Lab Passed: 'nginx' service is running on server1."
    else
        print_status "failed" "Lab Failed: 'nginx' service is not running on server1."
        exit 1
    fi
}

git_installation_check
nginx_service_check
exit 0

ansible -i "/home/user/workspace/inventory.ini" web -m shell -a "systemctl is-active nginx"