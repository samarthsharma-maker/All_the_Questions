#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

function load_config() {
    local config="/home/user/craftify-deploy-lab/lab-config.txt"
    if [ ! -f "$config" ]; then
        print_status "failed" "Lab Failed: Lab config not found. Run the setup script first."
        exit 1
    fi
    source "$config"
}

function test_agent_is_running() {
    load_config

    local agent_status
    agent_status=$(ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        ec2-user@"$INSTANCE_IP" \
        "systemctl is-active codedeploy-agent" 2>/dev/null || echo "")

    if [ "$agent_status" != "active" ]; then
        print_status "failed" "Lab Failed: CodeDeploy agent is not running on the instance (status: '$agent_status'). SSH into the instance and run: sudo systemctl start codedeploy-agent"
        exit 1
    fi
    print_status "success" "Lab Passed: CodeDeploy agent is running."
}

function test_agent_is_enabled() {
    load_config

    local enabled_status
    enabled_status=$(ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        ec2-user@"$INSTANCE_IP" \
        "systemctl is-enabled codedeploy-agent" 2>/dev/null || echo "")

    if [ "$enabled_status" != "enabled" ]; then
        print_status "failed" "Lab Failed: CodeDeploy agent is not enabled on boot (status: '$enabled_status'). Run: sudo systemctl enable codedeploy-agent"
        exit 1
    fi
    print_status "success" "Lab Passed: CodeDeploy agent is enabled on boot."
}

test_agent_is_running
test_agent_is_enabled

print_status "success" "Lab Passed: CodeDeploy agent is running and enabled on the EC2 instance."
exit 0