#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

PLAYBOOK="/home/user/vaultcore-ansible-lab/hardening.yml"

Test1() {

    if [ ! -f "${PLAYBOOK}" ]; then
        print_status "failed" "Playbook not found at /home/user/vaultcore-ansible-lab/hardening.yml. Ensure the setup script has been run."
        exit 0
    fi

    print_status "success" "Playbook file exists at /home/user/vaultcore-ansible-lab/hardening.yml."
}

Test2() {

    if [ ! -f "${PLAYBOOK}" ]; then
        print_status "failed" "Playbook not found. Ensure the setup script has been run."
        exit 0
    fi

    CONTENT=$(cat "${PLAYBOOK}" | sed 's/#.*//')

    # Check the non-idempotent shell useradd is gone
    if echo "${CONTENT}" | grep -q "shell:.*useradd"; then
        print_status "failed" "The 'Create deploy user' task still uses 'shell: useradd'. This is not idempotent — on a second run, useradd exits with code 9 because the user already exists, failing the entire play. Replace the shell task with the ansible.builtin.user module: set 'name: \"{{ deploy_user }}\"' and 'state: present'."
        exit 0
    fi

    # Check ansible.builtin.user is used
    if echo "${CONTENT}" | grep -q "ansible.builtin.user"; then
        print_status "success" "User creation task correctly uses the ansible.builtin.user module."
    else
        print_status "failed" "No 'ansible.builtin.user' module found for user creation. The task must use 'ansible.builtin.user' with 'name: \"{{ deploy_user }}\"' and 'state: present' to be idempotent — built-in modules check current state and skip changes that are already applied."
        exit 0
    fi
}

Test1
Test2