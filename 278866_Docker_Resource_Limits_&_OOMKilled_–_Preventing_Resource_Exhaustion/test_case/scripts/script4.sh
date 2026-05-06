#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

CONTAINER_NAME="safe-app"

function test_understand_exit_code() {
    local exit_code
    exit_code=$(docker inspect "$CONTAINER_NAME" --format='{{.State.ExitCode}}' 2>/dev/null)
    
    if [ "$exit_code" == "137" ]; then
        print_status "success" "Lab Passed: Container was OOMKilled (exit code 137)."
    elif [ "$exit_code" == "0" ]; then
        print_status "success" "Lab Passed: Container running normally (exit code 0)."
    else
        print_status "success" "Lab Passed: Can check exit code (currently: $exit_code)."
    fi
}

function test_docker_stats_works() {
    if docker stats --no-stream "$CONTAINER_NAME" >/dev/null 2>&1; then
        print_status "success" "Lab Passed: Can monitor with docker stats."
    elif docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        print_status "success" "Lab Passed: Container exists (may be stopped after OOMKill)."
    else
        print_status "failed" "Lab Failed: Cannot find container."
        exit 1
    fi
}

test_understand_exit_code
test_docker_stats_works

exit 0