#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

IMAGE_NAME="banking-app:secure"
CONTAINER_NAME="banking-app-secure"

function test_readonly_filesystem() {
    local readonly_rootfs
    readonly_rootfs=$(docker inspect "$CONTAINER_NAME" --format='{{.HostConfig.ReadonlyRootfs}}' 2>/dev/null)
    
    if [ "$readonly_rootfs" != "true" ]; then
        print_status "failed" "Lab Failed: Read-only root filesystem not enabled. Must use --read-only flag."
        exit 1
    fi
    
    # Test that root filesystem is actually read-only
    if docker exec "$CONTAINER_NAME" touch /test.txt 2>&1 | grep -q "Read-only file system"; then
        print_status "success" "Lab Passed: Read-only root filesystem enabled and verified."
    else
        print_status "failed" "Lab Failed: Filesystem appears to be writable."
        exit 1
    fi
}

function test_not_privileged() {
    local privileged
    privileged=$(docker inspect "$CONTAINER_NAME" --format='{{.HostConfig.Privileged}}' 2>/dev/null)
    
    if [ "$privileged" == "true" ]; then
        print_status "failed" "Lab Failed: Container running in privileged mode. Remove --privileged flag."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Container not running in privileged mode."
}

test_readonly_filesystem
test_not_privileged

exit 0
