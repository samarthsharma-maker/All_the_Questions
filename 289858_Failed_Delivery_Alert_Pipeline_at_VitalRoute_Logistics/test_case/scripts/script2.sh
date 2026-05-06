#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
QUEUE_NAME="vitalroute-failed-delivery-queue"
DLQ_NAME="vitalroute-failed-delivery-dlq"

function test_main_queue_exists() {
    local queue_url
    queue_url=$(aws sqs get-queue-url --queue-name "$QUEUE_NAME" --region "$REGION" --query "QueueUrl" --output text 2>/dev/null || echo "")

    if [ -z "$queue_url" ]; then
        print_status "failed" "Lab Failed: Main queue '$QUEUE_NAME' does not exist. Create it with the redrive policy attached."
        exit 1
    fi
    print_status "success" "Lab Passed: Main queue '$QUEUE_NAME' exists."
}

function test_redrive_policy_set() {
    local queue_url redrive_policy
    queue_url=$(aws sqs get-queue-url --queue-name "$QUEUE_NAME" --region "$REGION" --query "QueueUrl" --output text 2>/dev/null || echo "")
    redrive_policy=$(aws sqs get-queue-attributes --queue-url "$queue_url" --attribute-names RedrivePolicy --region "$REGION" --query "Attributes.RedrivePolicy" --output text 2>/dev/null || echo "")

    if [ -z "$redrive_policy" ] || [ "$redrive_policy" == "None" ]; then
        print_status "failed" "Lab Failed: No redrive policy found on '$QUEUE_NAME'. Attach the redrive-policy.json to wire the DLQ."
        exit 1
    fi
    print_status "success" "Lab Passed: Redrive policy is set on the main queue."
}

function test_redrive_points_to_dlq() {
    local queue_url redrive_policy dlq_arn expected_arn
    queue_url=$(aws sqs get-queue-url --queue-name "$QUEUE_NAME" --region "$REGION" --query "QueueUrl" --output text 2>/dev/null || echo "")
    redrive_policy=$(aws sqs get-queue-attributes --queue-url "$queue_url" --attribute-names RedrivePolicy --region "$REGION" --query "Attributes.RedrivePolicy" --output text 2>/dev/null || echo "")
    expected_arn="arn:aws:sqs:${REGION}:${ACCOUNT_ID}:${DLQ_NAME}"

    if ! echo "$redrive_policy" | grep -q "$expected_arn"; then
        print_status "failed" "Lab Failed: Redrive policy does not point to '$DLQ_NAME'. Ensure the deadLetterTargetArn in redrive-policy.json matches the DLQ ARN."
        exit 1
    fi
    print_status "success" "Lab Passed: Redrive policy correctly points to the DLQ."
}

function test_max_receive_count() {
    local queue_url redrive_policy max_receive
    queue_url=$(aws sqs get-queue-url --queue-name "$QUEUE_NAME" --region "$REGION" --query "QueueUrl" --output text 2>/dev/null || echo "")
    redrive_policy=$(aws sqs get-queue-attributes --queue-url "$queue_url" --attribute-names RedrivePolicy --region "$REGION" --query "Attributes.RedrivePolicy" --output text 2>/dev/null || echo "")
    max_receive=$(echo "$redrive_policy" | jq -r '.maxReceiveCount' 2>/dev/null || echo "")

    if [ "$max_receive" != "3" ]; then
        print_status "failed" "Lab Failed: maxReceiveCount is '$max_receive', expected '3'. Update the redrive policy on the main queue."
        exit 1
    fi
    print_status "success" "Lab Passed: maxReceiveCount is correctly set to 3."
}

test_main_queue_exists
test_redrive_policy_set
test_redrive_points_to_dlq
test_max_receive_count

print_status "success" "Lab Passed: Main queue is correctly configured with DLQ wired in and maxReceiveCount set to 3."
exit 0