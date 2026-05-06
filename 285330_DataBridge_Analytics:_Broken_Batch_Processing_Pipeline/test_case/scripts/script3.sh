#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

CRON_FILE="/etc/cron.d/databridge-cleanup"
HEALTHCHECK="/usr/local/bin/databridge-healthcheck"

Test5() {
    if [ ! -f "${CRON_FILE}" ]; then
        print_status "failed" "Cron file not found at /etc/cron.d/databridge-cleanup."
        return
    fi

    CONTENT=$(cat "${CRON_FILE}" | sed 's/#.*//')

    # Determine how the script is invoked: by name or full path
    invocation=$(echo "${CONTENT}" | grep -v '^\s*$' | grep -oE '(databridge-cleanup|/[^ ]+databridge-cleanup)' | tail -1)

    if [ -z "$invocation" ]; then
        print_status "failed" "Could not find the cleanup script invocation in ${CRON_FILE}. Ensure the cron entry calls 'databridge-cleanup' or its full path."
        return
    fi

    # If called by full path — always fine, PATH is irrelevant
    if echo "${invocation}" | grep -q '^/'; then
        print_status "success" "Cron job invokes cleanup script by full path ('${invocation}') — PATH is not required."
        return
    fi

    # Called by bare name — must have PATH including /usr/local/bin
    path_line=$(echo "${CONTENT}" | grep -E '^\s*PATH\s*=' | head -1)

    if [ -z "$path_line" ]; then
        print_status "failed" "The cron job calls 'databridge-cleanup' by name but no PATH is set in ${CRON_FILE}. Cron's default PATH is /usr/bin:/bin — /usr/local/bin is not included, so the script is never found and silently fails. Fix: either add 'PATH=/usr/local/bin:/usr/bin:/bin' at the top of the cron file, or invoke the script by its full path: /usr/local/bin/databridge-cleanup"
        return
    fi

    path_value=$(echo "${path_line}" | sed 's/.*PATH\s*=\s*//')

    if ! echo "${path_value}" | grep -q '/usr/local/bin'; then
        print_status "failed" "PATH is set in ${CRON_FILE} but does not include /usr/local/bin (current value: '${path_value}'). The cleanup script lives at /usr/local/bin/databridge-cleanup and cannot be found without this path component."
        return
    fi

    print_status "success" "Cron job PATH includes /usr/local/bin — cleanup script can be found."
}

Test6() {
    if [ ! -f "${HEALTHCHECK}" ]; then
        print_status "failed" "Health-check script not found at /usr/local/bin/databridge-healthcheck."
        return
    fi

    CONTENT=$(cat "${HEALTHCHECK}" | sed 's/#.*//')

    # Check kill -9 / SIGKILL is gone
    if echo "${CONTENT}" | grep -qE 'kill\s+-9|kill\s+-SIGKILL'; then
        print_status "failed" "The health-check script uses 'kill -9' (SIGKILL) to recover the daemon. SIGKILL cannot be caught or ignored — it terminates the process immediately with no cleanup and completely bypasses systemd. The unit enters a failed state and does not recover cleanly. Replace the kill -9 block with: systemctl restart databridge"
        return
    fi

    # Check systemctl restart is used — strip quotes first so both
    # 'systemctl restart databridge' and 'systemctl restart "$SERVICE"' match
    CONTENT_STRIPPED=$(echo "${CONTENT}" | sed 's/["'"'"']//g')
    if ! echo "${CONTENT_STRIPPED}" | grep -qE 'systemctl[[:space:]]+restart[[:space:]]+(\$\{?SERVICE\}?|databridge)'; then
        print_status "failed" "The health-check script does not use 'systemctl restart databridge' for recovery. Service restarts must go through systemd so the full lifecycle (ExecStop, Restart policy, state tracking) is respected."
        return
    fi

    print_status "success" "Health-check script uses 'systemctl restart databridge' for clean, systemd-managed recovery."
}

Test5
Test6