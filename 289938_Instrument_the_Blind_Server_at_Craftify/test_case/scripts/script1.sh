#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

function load_config() {
    local config="/home/user/craftify-cw-lab/lab-config.txt"
    if [ ! -f "$config" ]; then
        print_status "failed" "Lab Failed: Lab config not found. Run the setup script first."
        exit 1
    fi
    source "$config"
}

function test_log_group_exists() {
    load_config

    local result
    result=$(aws logs describe-log-groups \
        --log-group-name-prefix "$LOG_GROUP" \
        --region "$REGION" \
        --query "logGroups[?logGroupName=='${LOG_GROUP}'].logGroupName" \
        --output text 2>/dev/null || echo "")

    if [ -z "$result" ] || [ "$result" == "None" ]; then
        print_status "failed" "Lab Failed: Log group '$LOG_GROUP' does not exist. Create it using the CloudWatch console or CLI."
        exit 1
    fi
    print_status "success" "Lab Passed: Log group '$LOG_GROUP' exists."
}

function test_agent_is_running() {
    load_config

    local agent_status
    agent_status=$(ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        ec2-user@"$INSTANCE_IP" \
        "systemctl is-active amazon-cloudwatch-agent" 2>/dev/null || echo "")

    if [ "$agent_status" != "active" ]; then
        print_status "failed" "Lab Failed: CloudWatch agent is not running on the instance (status: '$agent_status'). Configure and start it using the amazon-cloudwatch-agent-ctl command."
        exit 1
    fi
    print_status "success" "Lab Passed: CloudWatch agent is running."
}

function test_log_events_flowing() {
    load_config

    local stream_count
    stream_count=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --region "$REGION" \
        --query "length(logStreams)" \
        --output text 2>/dev/null || echo "0")

    if [ "$stream_count" == "0" ] || [ -z "$stream_count" ]; then
        print_status "failed" "Lab Failed: No log streams found in '$LOG_GROUP'. Ensure the CloudWatch agent is running and the config points to /var/log/craftify/app.log."
        exit 1
    fi

    local latest_event
    latest_event=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --query "logStreams[0].lastEventTimestamp" \
        --output text 2>/dev/null || echo "")

    if [ -z "$latest_event" ] || [ "$latest_event" == "None" ]; then
        print_status "failed" "Lab Failed: Log streams exist but no events have been received yet. Wait a minute for the agent to ship the first batch of logs."
        exit 1
    fi

    print_status "success" "Lab Passed: Log events are flowing into '$LOG_GROUP'."
}

test_log_group_exists
test_agent_is_running
test_log_events_flowing

print_status "success" "Lab Passed: CloudWatch agent is running and shipping logs to the log group."
exit 0