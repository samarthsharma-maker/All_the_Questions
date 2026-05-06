#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

PLAYBOOK="/home/user/nightowl-lab/deploy_agent.yml"

Test1() {
    if [ ! -f "${PLAYBOOK}" ]; then
        print_status "failed" "Playbook not found at /home/user/nightowl-lab/deploy_agent.yml. Ensure the setup script has been run."
        return
    fi
    print_status "success" "Playbook file exists at /home/user/nightowl-lab/deploy_agent.yml."
}

Test2() {
    if [ ! -f "${PLAYBOOK}" ]; then
        print_status "failed" "Playbook not found."
        return
    fi

    CONTENT=$(cat "${PLAYBOOK}" | sed 's/#.*//')
    template_block=$(echo "${CONTENT}" | \
        awk '/- name: Deploy agent config/{found=1} found && /- name:/ && !/Deploy agent config/{found=0} found{print}')

    if echo "${template_block}" | grep -q "changed_when: false"; then
        print_status "failed" "'changed_when: false' is present on the 'Deploy agent config' template task. Ansible only notifies handlers when a task result is 'changed' — forcing changed_when: false means the task is always marked 'ok' and the handler is never triggered, regardless of whether the file actually changed."
        return
    fi

    print_status "success" "The template task does not suppress change detection with 'changed_when: false'."
}

Test1
Test2