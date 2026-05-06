#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

CONTAINER_NAME="safe-app"

function test_memory_limit_set() {
    local memory_limit
    memory_limit=$(docker inspect "$CONTAINER_NAME" --format='{{.HostConfig.Memory}}' 2>/dev/null)
    
    if [ -z "$memory_limit" ] || [ "$memory_limit" -eq 0 ] 2>/dev/null; then
        print_status "failed" "Lab Failed: No memory limit set. Must use --memory flag."
        exit 1
    fi
    
    local memory_mb=$(( memory_limit / 1024 / 1024 ))
    print_status "success" "Lab Passed: Memory limit set (${memory_mb}MB)."
}

function test_cpu_limit_set() {
    local cpu_quota nano_cpus cpu_shares
    
    nano_cpus=$(docker inspect "$CONTAINER_NAME" --format='{{.HostConfig.NanoCpus}}')    
    cpu_quota=$(docker inspect "$CONTAINER_NAME" --format='{{.HostConfig.CpuQuota}}')    
    cpu_shares=$(docker inspect "$CONTAINER_NAME" --format='{{.HostConfig.CpuShares}}')
    
    if { [ -z "$nano_cpus" ] || [ "$nano_cpus" -eq 0 ]; } && \
       { [ -z "$cpu_quota" ] || [ "$cpu_quota" -eq 0 ]; } && \
       { [ -z "$cpu_shares" ] || [ "$cpu_shares" -eq 0 ] || [ "$cpu_shares" -eq 1024 ]; }; then
        print_status "failed" "Lab Failed: No CPU limit set."
        exit 1
    fi
    
    print_status "success" "Lab Passed: CPU limit set."
}

test_memory_limit_set
test_cpu_limit_set

exit 0