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

function test_alarm_exists() {
    load_config

    local alarm_state
    alarm_state=$(aws cloudwatch describe-alarms \
        --alarm-names "$ALARM_NAME" \
        --region "$REGION" \
        --query "MetricAlarms[0].StateValue" \
        --output text 2>/dev/null || echo "")

    if [ -z "$alarm_state" ] || [ "$alarm_state" == "None" ]; then
        print_status "failed" "Lab Failed: CloudWatch alarm '$ALARM_NAME' does not exist. Create it on the ErrorCount metric with a threshold of 1."
        exit 1
    fi
    print_status "success" "Lab Passed: Alarm '$ALARM_NAME' exists (state: $alarm_state)."
}

function test_alarm_wired_to_sns() {
    load_config

    local alarm_action
    alarm_action=$(aws cloudwatch describe-alarms \
        --alarm-names "$ALARM_NAME" \
        --region "$REGION" \
        --query "MetricAlarms[0].AlarmActions[0]" \
        --output text 2>/dev/null || echo "")

    if [ -z "$alarm_action" ] || [ "$alarm_action" == "None" ]; then
        print_status "failed" "Lab Failed: Alarm '$ALARM_NAME' has no alarm action configured. Wire it to the SNS topic '$SNS_TOPIC_NAME'."
        exit 1
    fi

    if ! echo "$alarm_action" | grep -q "$SNS_TOPIC_NAME"; then
        print_status "failed" "Lab Failed: Alarm action '$alarm_action' does not reference SNS topic '$SNS_TOPIC_NAME'. Update the alarm actions."
        exit 1
    fi
    print_status "success" "Lab Passed: Alarm is wired to SNS topic '$SNS_TOPIC_NAME'."
}

function test_alarm_has_fired() {
    load_config

    local alarm_state
    alarm_state=$(aws cloudwatch describe-alarms \
        --alarm-names "$ALARM_NAME" \
        --region "$REGION" \
        --query "MetricAlarms[0].StateValue" \
        --output text 2>/dev/null || echo "")

    # Check SQS first for messages
    local visible not_visible total
    visible=$(aws sqs get-queue-attributes \
        --queue-url "$SQS_URL" \
        --attribute-names ApproximateNumberOfMessages \
        --region "$REGION" \
        --query "Attributes.ApproximateNumberOfMessages" \
        --output text 2>/dev/null || echo "0")

    not_visible=$(aws sqs get-queue-attributes \
        --queue-url "$SQS_URL" \
        --attribute-names ApproximateNumberOfMessagesNotVisible \
        --region "$REGION" \
        --query "Attributes.ApproximateNumberOfMessagesNotVisible" \
        --output text 2>/dev/null || echo "0")

    total=$(( ${visible:-0} + ${not_visible:-0} ))

    # Pass if SQS has messages OR alarm is currently in ALARM state
    if [ "$total" -gt 0 ]; then
        print_status "success" "Lab Passed: SQS queue has received $total notification(s) from SNS. Alarm fired successfully."
        return 0
    fi

    if [ "$alarm_state" == "ALARM" ]; then
        print_status "success" "Lab Passed: Alarm is in ALARM state — SNS notification was fired."
        return 0
    fi

    # Also check alarm history for any previous ALARM transitions
    local alarm_fired
    alarm_fired=$(aws cloudwatch describe-alarm-history \
        --alarm-name "$ALARM_NAME" \
        --history-item-type StateUpdate \
        --region "$REGION" \
        --query "AlarmHistoryItems[?contains(HistorySummary,'ALARM')].AlarmName" \
        --output text 2>/dev/null || echo "")

    if [ -n "$alarm_fired" ] && [ "$alarm_fired" != "None" ]; then
        print_status "success" "Lab Passed: Alarm history confirms the alarm has fired. SNS notification was delivered."
        return 0
    fi

    print_status "failed" "Lab Failed: No evidence the alarm has fired. Inject an ERROR line into the app log and wait 90-120 seconds for the alarm to fire."
    exit 1
}

test_alarm_exists
test_alarm_wired_to_sns
test_alarm_has_fired

print_status "success" "Lab Passed: Alarm exists, is wired to SNS, and has fired successfully."
exit 0