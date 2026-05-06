#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

REGION="us-west-2"
MOUNT_POINT="/mnt/efs"
TEST_FILE="driver.log"

function load_config() {
    local config="/home/user/vitalroute-efs-lab/lab-config.txt"
    if [ ! -f "$config" ]; then
        print_status "failed" "Lab Failed: Lab config file not found. Run the setup script first."
        exit 1
    fi
    source "$config"
}

function test_file_exists_on_instance_1() {
    load_config

    local file_check
    file_check=$(ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        ec2-user@"$IP_1" \
        "cat ${MOUNT_POINT}/${TEST_FILE}" 2>/dev/null || echo "")

    if [ -z "$file_check" ]; then
        print_status "failed" "Lab Failed: '$TEST_FILE' not found on server-1 at '$MOUNT_POINT'. Complete Task 4 — write a driver log entry to the shared EFS mount from server-1."
        exit 1
    fi

    print_status "success" "Lab Passed: $TEST_FILE exists on server-1 with content: $(echo $file_check | cut -c1-60)"
}

function test_file_visible_on_instance_2() {
    load_config

    local file_check_1 file_check_2
    file_check_1=$(ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        ec2-user@"$IP_1" \
        "cat ${MOUNT_POINT}/${TEST_FILE}" 2>/dev/null || echo "")

    file_check_2=$(ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        ec2-user@"$IP_2" \
        "cat ${MOUNT_POINT}/${TEST_FILE}" 2>/dev/null || echo "")

    if [ -z "$file_check_2" ]; then
        print_status "failed" "Lab Failed: '$TEST_FILE' is not visible on server-2. Ensure EFS is mounted on server-2 and the file was written to '$MOUNT_POINT' on server-1."
        exit 1
    fi

    if [ "$file_check_1" != "$file_check_2" ]; then
        print_status "failed" "Lab Failed: File content on server-1 and server-2 does not match. Both instances should be reading from the same EFS filesystem."
        exit 1
    fi

    print_status "success" "Lab Passed: File written on server-1 is visible on server-2 with identical content. Shared filesystem is working."
}

test_file_exists_on_instance_1
test_file_visible_on_instance_2

print_status "success" "Lab Passed: EFS shared filesystem is working correctly. Files written on server-1 are visible on server-2 in real time."
exit 0