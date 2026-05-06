#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

PLAYBOOK="/home/user/nightowl-lab/deploy_agent.yml"

Test3() {
    if [ ! -f "${PLAYBOOK}" ]; then
        print_status "failed" "Playbook not found."
        return
    fi

    CONTENT=$(cat "${PLAYBOOK}" | sed 's/#.*//')

    if echo "${CONTENT}" | grep -q "failed_when: false"; then
        print_status "failed" "'failed_when: false' is present in the playbook. This tells Ansible to never fail the task regardless of the command's exit code — the validation step becomes a no-op that silently passes even when the config is invalid or the check tool reports an error."
        return
    fi

    print_status "success" "No task suppresses failure handling with 'failed_when: false'."
}

Test4() {
    if [ ! -f "${PLAYBOOK}" ]; then
        print_status "failed" "Playbook not found."
        return
    fi

    CONTENT=$(cat "${PLAYBOOK}" | sed 's/#.*//')

    # Check that a loop_var override is present
    if ! echo "${CONTENT}" | grep -q "loop_var:"; then
        print_status "failed" "No 'loop_var' directive found. The package installation task uses loop_control with a custom loop_var — the task body must reference the correct variable name."
        return
    fi

    # Extract the custom loop_var name
    loop_var_name=$(echo "${CONTENT}" | grep -A1 "loop_control:" | grep "loop_var:" | awk '{print $2}' | tr -d '"' | head -1)

    # Check that {{ item }} is NOT used when loop_var is overridden
    if echo "${CONTENT}" | grep -q "\"{{ item }}\""; then
        print_status "failed" "The package installation task uses '{{ item }}' but loop_control overrides the loop variable to '{{ ${loop_var_name} }}'. When loop_var is set, 'item' is no longer defined — Ansible raises AnsibleUndefinedVariable. The task body must use '{{ ${loop_var_name} }}' instead."
        return
    fi

    # Verify the correct loop var is used in the apt task
    if echo "${CONTENT}" | grep -q "\"{{ ${loop_var_name} }}\""; then
        print_status "success" "Package installation task correctly references '{{ ${loop_var_name} }}' matching the loop_var definition."
    else
        print_status "failed" "Package installation task does not reference the loop variable '{{ ${loop_var_name} }}'. Ensure the apt module's 'name' field uses the variable defined in loop_control.loop_var."
    fi
}

Test3
Test4