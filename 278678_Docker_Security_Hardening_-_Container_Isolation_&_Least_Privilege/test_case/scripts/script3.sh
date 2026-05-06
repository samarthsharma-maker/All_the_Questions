#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

IMAGE_NAME="banking-app:secure"
CONTAINER_NAME="banking-app-secure"

function test_resource_limits() {
    local memory_limit cpu_quota
    
    memory_limit=$(docker inspect "$CONTAINER_NAME" --format='{{.HostConfig.Memory}}' 2>/dev/null)
    cpu_quota=$(docker inspect "$CONTAINER_NAME" --format='{{.HostConfig.CpuQuota}}' 2>/dev/null)
    
    if [ -z "$memory_limit" ] || [ "$memory_limit" -eq 0 ] 2>/dev/null; then
        print_status "failed" "Lab Failed: No memory limit set. Must set --memory flag."
        exit 1
    fi
    
    if [ -z "$cpu_quota" ] || [ "$cpu_quota" -eq 0 ] 2>/dev/null; then
        print_status "failed" "Lab Failed: No CPU limit set. Must set --cpus flag."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Resource limits applied (Memory: $memory_limit bytes, CPU quota: $cpu_quota)."
}

function test_capabilities_dropped() {
    local cap_drop
    cap_drop=$(docker inspect "$CONTAINER_NAME" --format='{{.HostConfig.CapDrop}}' 2>/dev/null)
    
    if [ -z "$cap_drop" ] || [ "$cap_drop" == "[]" ]; then
        print_status "failed" "Lab Failed: No capabilities dropped. Must use --cap-drop=ALL."
        exit 1
    fi
    
    if ! echo "$cap_drop" | grep -qi "ALL"; then
        print_status "failed" "Lab Failed: Must drop ALL capabilities with --cap-drop=ALL."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Capabilities dropped (CapDrop: $cap_drop)."
}

test_resource_limits
test_capabilities_dropped

exit 0
