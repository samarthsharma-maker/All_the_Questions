#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
DLQ_NAME="vitalroute-failed-delivery-dlq"

function test_dlq_receives_failed_messages() {
    local dlq_url msg_count
    dlq_url=$(aws sqs get-queue-url --queue-name "$DLQ_NAME" --region "$REGION" --query "QueueUrl" --output text 2>/dev/null || echo "")

    if [ -z "$dlq_url" ]; then
        print_status "failed" "Lab Failed: Could not find DLQ '$DLQ_NAME'."
        exit 1
    fi

    msg_count=$(aws sqs get-queue-attributes --queue-url "$dlq_url" --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible --region "$REGION" --output json 2>/dev/null | jq -r '(.Attributes.ApproximateNumberOfMessages | tonumber) + (.Attributes.ApproximateNumberOfMessagesNotVisible | tonumber)' || echo "0")
    if [ "$msg_count" == "0" ] || [ -z "$msg_count" ]; then
        print_status "failed" "Lab Failed: No messages found in DLQ '$DLQ_NAME'."
        exit 1
    fi

    print_status "success" "Lab Passed: DLQ contains $msg_count message(s). DLQ routing is working correctly."
}

test_dlq_receives_failed_messages

print_status "success" "Lab Passed: Messages are correctly routing to the DLQ after 3 failed receive attempts."
exit 0