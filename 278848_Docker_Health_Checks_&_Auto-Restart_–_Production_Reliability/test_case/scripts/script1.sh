#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep checkout | head -n 1)

function test_container_exists() {
    if [ -z "$CONTAINER_NAME" ]; then
        print_status "failed" "Lab Failed: checkout container is not running."
        exit 1
    fi
    print_status "success" "Container is running: $CONTAINER_NAME"
}

function test_healthcheck_exists() {
    local hc
    hc=$(docker inspect "$CONTAINER_NAME" --format='{{.Config.Healthcheck}}' 2>/dev/null)

    if [ "$hc" == "<nil>" ]; then
        print_status "failed" "Lab Failed: HEALTHCHECK is not configured in Dockerfile."
        exit 1
    fi

    print_status "success" "HEALTHCHECK is configured."
}

function test_restart_policy() {
    local policy
    policy=$(docker inspect "$CONTAINER_NAME" \
        --format='{{.HostConfig.RestartPolicy.Name}}')

    if [ "$policy" != "unless-stopped" ]; then
        print_status "failed" \
          "Lab Failed: Restart policy must be unless-stopped. Found: '$policy'"
        exit 1
    fi

    print_status "success" "Restart policy is correctly set to unless-stopped."
}

test_container_exists
test_healthcheck_exists
test_restart_policy

exit 0
