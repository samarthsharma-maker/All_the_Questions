#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

REGION="us-west-2"
MOUNT_POINT="/mnt/efs"

function load_config() {
    local config="/home/user/vitalroute-efs-lab/lab-config.txt"
    if [ ! -f "$config" ]; then
        print_status "failed" "Lab Failed: Lab config file not found. Run the setup script first."
        exit 1
    fi
    source "$config"
}

function test_efs_mounted_on_instance_1() {
    load_config

    # Attempt mount in case learner fixed SG but hasn't run mount -a yet
    ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        ec2-user@"$IP_1" \
        "sudo mount -a > /dev/null 2>&1 || true"

    local mount_check
    mount_check=$(ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        ec2-user@"$IP_1" \
        "df -h | grep '$MOUNT_POINT'" 2>/dev/null || echo "")

    if [ -z "$mount_check" ]; then
        print_status "failed" "Lab Failed: EFS is not mounted on server-1 at '$MOUNT_POINT'. Fix the EFS security group first — it must allow port 2049 from the EC2 security group."
        exit 1
    fi

    print_status "success" "Lab Passed: EFS is mounted on server-1 at $MOUNT_POINT."
}

function test_efs_mounted_on_instance_2() {
    load_config

    # Attempt mount in case learner added fstab but hasn't run mount -a yet
    ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        ec2-user@"$IP_2" \
        "sudo mount -a > /dev/null 2>&1 || true"

    local mount_check
    mount_check=$(ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        ec2-user@"$IP_2" \
        "df -h | grep '$MOUNT_POINT'" 2>/dev/null || echo "")

    if [ -z "$mount_check" ]; then
        print_status "failed" "Lab Failed: EFS is not mounted on server-2 at '$MOUNT_POINT'. Add the correct fstab entry on server-2 and run 'sudo mount -a'."
        exit 1
    fi

    print_status "success" "Lab Passed: EFS is mounted on server-2 at $MOUNT_POINT."
}

function test_fstab_entry_on_instance_2() {
    load_config

    local fstab_check
    fstab_check=$(ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        ec2-user@"$IP_2" \
        "grep '$MOUNT_POINT' /etc/fstab" 2>/dev/null || echo "")

    if [ -z "$fstab_check" ]; then
        print_status "failed" "Lab Failed: No fstab entry found for '$MOUNT_POINT' on server-2. Add the EFS fstab entry so the mount persists across reboots."
        exit 1
    fi

    if ! echo "$fstab_check" | grep -q "_netdev"; then
        print_status "failed" "Lab Failed: fstab entry on server-2 is missing the '_netdev' option. This ensures EFS is mounted after the network is available on boot."
        exit 1
    fi

    print_status "success" "Lab Passed: fstab entry with _netdev option exists on server-2."
}

test_efs_mounted_on_instance_1
test_efs_mounted_on_instance_2
test_fstab_entry_on_instance_2

print_status "success" "Lab Passed: EFS is correctly mounted on both server-1 and server-2 with a persistent fstab entry."
exit 0