#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

PLAYBOOK="/home/user/nightowl-lab/deploy_agent.yml"
INVENTORY="/home/user/nightowl-lab/inventory.ini"

Test5() {
    if [ ! -f "${PLAYBOOK}" ]; then
        print_status "failed" "Playbook not found."
        return
    fi

    CONTENT=$(cat "${PLAYBOOK}")

    # Find line numbers for the stat task (which registers config_stat)
    # and the task that uses config_stat in a when condition
    stat_line=$(echo "${CONTENT}" | grep -n "register: config_stat" | head -1 | cut -d: -f1)
    when_line=$(echo "${CONTENT}" | grep -n "config_stat.stat" | head -1 | cut -d: -f1)

    if [ -z "$stat_line" ]; then
        print_status "failed" "No task found that registers 'config_stat' via ansible.builtin.stat. The pre-flight check requires a stat task to populate this variable before it is referenced."
        return
    fi

    if [ -z "$when_line" ]; then
        print_status "failed" "No task found that references 'config_stat.stat' in a when condition. Ensure the pre-flight directory check uses 'when: not config_stat.stat.exists'."
        return
    fi

    if [ "${stat_line}" -gt "${when_line}" ]; then
        print_status "failed" "Task ordering issue: 'config_stat' is referenced on line ${when_line} but the stat task that registers it appears on line ${stat_line}. Ansible executes tasks sequentially — a registered variable does not exist until the task that registers it has run. Move the stat task above the task that references config_stat."
        return
    fi

    print_status "success" "Stat task (line ${stat_line}) correctly appears before the task that references config_stat (line ${when_line})."
}

Test6() {
    if [ ! -f "${PLAYBOOK}" ]; then
        print_status "failed" "Playbook not found. Ensure all fixes have been applied."
        return
    fi

    if [ ! -f "${INVENTORY}" ]; then
        print_status "failed" "Inventory not found at /home/user/nightowl-lab/inventory.ini."
        return
    fi

    # Resolve target IP from /etc/hosts if inventory still has bare hostname
    if ! grep -qE '^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "${INVENTORY}"; then
        local found_ip
        found_ip=$(grep -E '\bserver1\b' /etc/hosts | awk '{print $1}' | head -1)
        if [ -z "$found_ip" ]; then
            print_status "failed" "'server1' not found in /etc/hosts. Ensure the target container is running."
            return
        fi
        sed -i "s/^target$/${found_ip}/" "${INVENTORY}"
    fi

    cd /home/user/nightowl-lab

    # First run — must succeed
    first_output=$(ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" 2>&1)
    first_exit=$?

    if [ "${first_exit}" -ne 0 ]; then
        error_line=$(echo "${first_output}" | grep -E "^(TASK|fatal|ERROR)" | tail -3 | tr '\n' ' ')
        print_status "failed" "Playbook failed on the first run (exit code ${first_exit}). Fix all four bugs before re-running. Last error context: ${error_line}"
        return
    fi

    # Second run — must be idempotent
    second_output=$(ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" 2>&1)
    second_exit=$?

    if [ "${second_exit}" -ne 0 ]; then
        print_status "failed" "Playbook failed on the second (idempotency) run. Every task must check current state and skip if already applied."
        return
    fi

    changed_count=$(echo "${second_output}" | grep -oP 'changed=\K[0-9]+' | head -1)
    changed_count=${changed_count:-0}

    if [ "${changed_count}" -gt 0 ]; then
        print_status "failed" "Playbook is not idempotent — second run reported ${changed_count} changed task(s). Review all tasks for non-idempotent patterns."
        return
    fi

    print_status "success" "Playbook ran successfully and is idempotent — second run reported 0 changes."
}

Test5
Test6