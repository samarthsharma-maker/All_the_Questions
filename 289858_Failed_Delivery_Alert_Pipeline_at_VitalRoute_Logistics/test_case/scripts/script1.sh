#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

REGION="us-west-2"
DLQ_NAME="vitalroute-failed-delivery-dlq"

function test_dlq_exists() {
    local dlq_url
    dlq_url=$(aws sqs get-queue-url --queue-name "$DLQ_NAME" --region "$REGION" --query "QueueUrl" --output text 2>/dev/null || echo "")

    if [ -z "$dlq_url" ]; then
        print_status "failed" "Lab Failed: DLQ '$DLQ_NAME' does not exist. Create it using aws sqs command or the console"
        exit 1
    fi
    print_status "success" "Lab Passed: DLQ '$DLQ_NAME' exists."
}

function test_dlq_is_standard_queue() {
    local dlq_url fifo
    dlq_url=$(aws sqs get-queue-url --queue-name "$DLQ_NAME" --region "$REGION" --query "QueueUrl" --output text 2>/dev/null || echo "")
    fifo=$(aws sqs get-queue-attributes --queue-url "$dlq_url" --attribute-names FifoQueue --region "$REGION" --query "Attributes.FifoQueue" --output text 2>/dev/null || echo "false")

    if [ "$fifo" == "true" ]; then
        print_status "failed" "Lab Failed: '$DLQ_NAME' is a FIFO queue. Create a standard queue instead."
        exit 1
    fi
    print_status "success" "Lab Passed: DLQ is a standard queue."
}

test_dlq_exists
test_dlq_is_standard_queue

print_status "success" "Lab Passed: Dead Letter Queue is correctly created."
exit 0