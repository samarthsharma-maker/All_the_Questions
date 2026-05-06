#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

IMAGE="pulse-agent:v2"
CONTAINER="pulse-agent-staging"
NETWORK="novapulse-net"

function test_container_running_on_network() {
    local state
    state=$(docker inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null || true)

    if [ -z "$state" ]; then
        print_status "failed" "Lab Failed: Container '$CONTAINER' not found. Run it on $NETWORK with the correct configuration."
        exit 1
    fi
    if [ "$state" != "running" ]; then
        print_status "failed" "Lab Failed: Container '$CONTAINER' is '$state' — must be 'running'. Check: docker logs $CONTAINER"
        exit 1
    fi

    local networks
    networks=$(docker inspect "$CONTAINER" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}')

    if ! echo "$networks" | grep -qw "$NETWORK"; then
        print_status "failed" "Lab Failed: Container '$CONTAINER' is not connected to '$NETWORK' (on: '${networks:-none}')."
        exit 1
    fi
    print_status "success" "Lab Passed: Container '$CONTAINER' is running on '$NETWORK'."
}


function test_container_app_env_staging() {
    if ! docker inspect "$CONTAINER" &>/dev/null; then
        print_status "failed" "Lab Failed [C]: Container '$CONTAINER' not found."
        exit 1
    fi

    local val
    val=$(docker inspect "$CONTAINER" --format '{{json .Config.Env}}' | grep -o '"APP_ENV=[^"]*"' | awk -F= '{print $2}' | tr -d '"')

    if [ -z "$val" ]; then
        print_status "failed" "Lab Failed [C]: APP_ENV is not set on container '$CONTAINER'."
        exit 1
    fi
    if [ "$val" != "staging" ]; then
        print_status "failed" "Lab Failed [C]: Container '$CONTAINER' has APP_ENV='$val'. Investigate the running container, find the issue, and correct it."
        exit 1
    fi
    print_status "success" "Lab Passed [C]: Container '$CONTAINER' has APP_ENV=staging."
}

test_container_running_on_network
test_container_app_env_staging
print_status "success" "Lab Passed: Container runtime and network configuration are correct. All tests passed!"
exit 0
