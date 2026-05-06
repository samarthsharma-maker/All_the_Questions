#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

CONTAINER_NAME="safe-app"

function test_memory_limit_reasonable() {
    local memory_limit
    memory_limit=$(docker inspect "$CONTAINER_NAME" --format='{{.HostConfig.Memory}}' 2>/dev/null)
    
    local max_limit=$(( 10 * 1024 * 1024 * 1024 ))
    if [ "$memory_limit" -gt "$max_limit" ]; then
        print_status "failed" "Lab Failed: Memory limit too high (>10GB). Set reasonable limit."
        exit 1
    fi
    print_status "success" "Lab Passed: Memory limit is reasonable."
}

function test_can_check_oom_status() {
    local oom_status
    oom_status=$(docker inspect "$CONTAINER_NAME" --format='{{.State.OOMKilled}}' 2>/dev/null)
    
    if [ -z "$oom_status" ]; then
        print_status "failed" "Lab Failed: Cannot check OOMKilled status."
        exit 1
    fi
    print_status "success" "Lab Passed: OOMKilled status available (currently: $oom_status)."
}

test_memory_limit_reasonable
test_can_check_oom_status

exit 0