#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

SERVICE_FILE="/etc/systemd/system/databridge.service"
CORRECT_CONF="/etc/databridge/databridge.conf"

Test1() {
    if [ ! -f "${SERVICE_FILE}" ]; then
        print_status "failed" "Service file not found at /etc/systemd/system/databridge.service."
        return
    fi

    # Check unit is enabled
    if ! systemctl is-enabled --quiet databridge 2>/dev/null; then
        print_status "failed" "databridge.service exists but is not enabled. Run: sudo systemctl enable databridge"
        return
    fi

    # Check service is active
    if ! systemctl is-active --quiet databridge 2>/dev/null; then
        print_status "failed" "databridge.service is not running. Run: sudo systemctl daemon-reload && sudo systemctl restart databridge"
        return
    fi

    print_status "success" "databridge.service is enabled and active."
}

Test2() {
    if [ ! -f "${SERVICE_FILE}" ]; then
        print_status "failed" "Service file not found at /etc/systemd/system/databridge.service."
        return
    fi

    # Extract the EnvironmentFile path from the unit (strip leading '-' if present)
    env_file_line=$(grep -E '^\s*EnvironmentFile=' "${SERVICE_FILE}" | head -1)

    if [ -z "$env_file_line" ]; then
        print_status "failed" "No EnvironmentFile directive found in databridge.service. The service needs to load its configuration from /etc/databridge/databridge.conf."
        return
    fi

    # Strip key, leading -, and whitespace to get the raw path
    env_file_path=$(echo "${env_file_line}" | sed 's/.*EnvironmentFile=//' | sed 's/^-//' | tr -d ' ')

    if [ "${env_file_path}" != "${CORRECT_CONF}" ]; then
        print_status "failed" "EnvironmentFile is set to '${env_file_path}' but the correct config file is '${CORRECT_CONF}'. The wrong path means environment variables (BATCH_FLAGS, BATCH_SIZE, DB_HOST) are never loaded — the daemon runs with an empty environment. Fix the EnvironmentFile path in the unit file, then run: sudo systemctl daemon-reload && sudo systemctl restart databridge"
        return
    fi

    # Verify the file actually exists at that path
    if [ ! -f "${env_file_path}" ]; then
        print_status "failed" "EnvironmentFile path '${env_file_path}' is correct in the unit, but the file does not exist on disk."
        return
    fi

    print_status "success" "EnvironmentFile correctly points to '${CORRECT_CONF}' which exists on disk."
}

Test1
Test2