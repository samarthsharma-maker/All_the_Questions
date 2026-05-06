#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep checkout | head -n 1)

function test_container_health_status() {
    local status
    status=$(docker inspect "$CONTAINER_NAME" \
        --format='{{.State.Health.Status}}' 2>/dev/null)

    if [ "$status" != "healthy" ]; then
        print_status "failed" \
          "Lab Failed: Container is not healthy. Found: '$status'"
        exit 1
    fi

    print_status "success" "Container health status is healthy."
}

test_container_health_status
exit 0
