#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

PLAYBOOK="/home/user/vaultcore-ansible-lab/hardening.yml"

Test3() {

    if [ ! -f "${PLAYBOOK}" ]; then
        print_status "failed" "Playbook not found. Ensure the setup script has been run."
        return
    fi

    CONTENT=$(cat "${PLAYBOOK}" | sed 's/#.*//')

    # Extract all notify values and all handler names
    notify_values=$(echo "${CONTENT}" | grep -E "^\s+notify:" | sed 's/.*notify:\s*//' | tr -d '"' | sort)
    handler_names=$(echo "${CONTENT}" | grep -A1 "handlers:" | grep -E "^\s+-\s+name:" | sed 's/.*name:\s*//' | tr -d '"' | sort)

    # Check that the broken notify string is gone
    if echo "${CONTENT}" | grep -q "notify:.*Restart SSH Service"; then
        print_status "failed" "The 'Deploy SSH banner' task still notifies 'Restart SSH Service' but the handler is named 'restart sshd'. Ansible matches notify strings case-sensitively and exactly — the handler will never be triggered and sshd will never restart after the banner changes. Fix: change the notify value to 'restart sshd' to match the handler name."
        exit 0
    fi

    # Check all notify strings have a matching handler
    # Both tasks should now notify 'restart sshd'
    if echo "${CONTENT}" | grep -E "^\s+notify:" | grep -qv "restart sshd"; then
        leftover=$(echo "${CONTENT}" | grep -E "^\s+notify:" | grep -v "restart sshd" | head -1 | sed 's/.*notify:\s*//')
        print_status "failed" "Notify value '${leftover}' does not match any handler name. Every notify string must exactly match a handler name. The only handler defined is 'restart sshd'."
        exit 0
    fi

    print_status "success" "All notify strings match handler names correctly."
}

Test4() {

    if [ ! -f "${PLAYBOOK}" ]; then
        print_status "failed" "Playbook not found. Ensure the setup script has been run."
        exit 0
    fi

    CONTENT=$(cat "${PLAYBOOK}" | sed 's/#.*//')

    if echo "${CONTENT}" | grep -q "become: false"; then
        print_status "failed" "'become: false' is still present in the playbook. The 'Write sudoers entry' task writes to /etc/sudoers.d/ which is owned by root — it requires privilege escalation. The 'become: false' override cancels the play-level 'become: true' for that specific task, causing a permission denied error. Remove 'become: false' from the sudoers task."
        exit 0
    fi

    print_status "success" "No task overrides privilege escalation with 'become: false'."
}

Test3
Test4