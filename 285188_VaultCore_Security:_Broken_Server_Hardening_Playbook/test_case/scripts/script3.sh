#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TEMPLATE="/home/user/vaultcore-ansible-lab/templates/ssh_banner.j2"
PLAYBOOK="/home/user/vaultcore-ansible-lab/hardening.yml"
INVENTORY="/home/user/vaultcore-ansible-lab/inventory.ini"

Test5() {

    if [ ! -f "${TEMPLATE}" ]; then
        print_status "failed" "Template not found at /home/user/vaultcore-ansible-lab/templates/ssh_banner.j2."
        exit 0
    fi

    TEMPLATE_CONTENT=$(cat "${TEMPLATE}" | sed 's/#.*//')

    # Check the broken variable reference is gone
    if echo "${TEMPLATE_CONTENT}" | grep -q "app_port"; then
        print_status "failed" "The template still references '{{ app_port }}'. This variable is not defined anywhere — vars.yml defines it as 'application_port'. Ansible raises AnsibleUndefinedVariable at render time and the task fails. Fix: change '{{ app_port }}' to '{{ application_port }}' in ssh_banner.j2."
        exit 0
    fi

    # Check the correct variable is used
    if echo "${TEMPLATE_CONTENT}" | grep -q "application_port"; then
        print_status "success" "Template correctly references '{{ application_port }}' which matches the variable defined in vars.yml."
    else
        print_status "failed" "Template does not reference 'application_port'. The port variable defined in vars.yml is 'application_port: 8443'. Update the template to use '{{ application_port }}'."
        exit 0
    fi
}

Test6() {

    if [ ! -f "${PLAYBOOK}" ]; then
        print_status "failed" "Playbook not found. Ensure all previous fixes have been applied."
        return
    fi

    if [ ! -f "${INVENTORY}" ]; then
        print_status "failed" "Inventory not found at /home/user/vaultcore-ansible-lab/inventory.ini."
        return
    fi

    # If inventory still has the bare hostname 'target', resolve it to an IP
    if ! grep -qE '^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "${INVENTORY}"; then
        local found_ip
        found_ip=$(grep -E '\bserver1\b' /etc/hosts | awk '{print $1}' | head -1)

        if [ -z "$found_ip" ]; then
            print_status "failed" "'server1' not found in /etc/hosts. Ensure the target container is running."
            return
        fi

        sed -i "s/^target$/${found_ip}/" "${INVENTORY}"
    fi

    cd /home/user/vaultcore-ansible-lab

    # First run — must succeed (exit 0)
    first_output=$(ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" 2>&1)
    first_exit=$?

    if [ "${first_exit}" -ne 0 ]; then
        # Surface the last meaningful error line to the candidate
        error_line=$(echo "${first_output}" | grep -E "^(TASK|fatal|ERROR)" | tail -3 | tr '\n' ' ')
        print_status "failed" "Playbook failed on the first run (exit code ${first_exit}). Fix all four bugs before re-running. Last error context: ${error_line}"
        return
    fi

    # Second run — must be fully idempotent (0 changed tasks)
    second_output=$(ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" 2>&1)
    second_exit=$?

    if [ "${second_exit}" -ne 0 ]; then
        print_status "failed" "Playbook failed on the second (idempotency) run. A correctly written Ansible playbook must be safe to re-run without errors or unintended changes."
        return
    fi

    changed_count=$(echo "${second_output}" | grep -oP 'changed=\K[0-9]+' | head -1)
    changed_count=${changed_count:-0}

    if [ "${changed_count}" -gt 0 ]; then
        print_status "failed" "Playbook is not idempotent — the second run reported ${changed_count} changed task(s). Every task must check current state and skip changes that are already applied. Review tasks that use shell/command modules or do not use 'state: present'."
        return
    fi

    print_status "success" "Playbook ran successfully and is idempotent — second run reported 0 changes."
}

Test5
Test6