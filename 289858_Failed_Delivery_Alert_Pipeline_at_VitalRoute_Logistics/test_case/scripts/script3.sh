#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
TOPIC_NAME="vitalroute-delivery-alerts"
QUEUE_NAME="vitalroute-failed-delivery-queue"

function test_sns_topic_exists() {
    local topic_arn
    topic_arn=$(aws sns list-topics --region "$REGION" --query "Topics[?contains(TopicArn, ':${TOPIC_NAME}')].TopicArn" --output text 2>/dev/null || echo "")

    if [ -z "$topic_arn" ]; then
        print_status "failed" "Lab Failed: SNS topic '$TOPIC_NAME' does not exist. Create it using aws sns commands or the console."
        exit 1
    fi
    print_status "success" "Lab Passed: SNS topic '$TOPIC_NAME' exists."
}

function test_queue_policy_allows_sns() {
    local queue_url policy topic_arn
    topic_arn="arn:aws:sns:${REGION}:${ACCOUNT_ID}:${TOPIC_NAME}"
    queue_url=$(aws sqs get-queue-url --queue-name "$QUEUE_NAME" --region "$REGION" --query "QueueUrl" --output text 2>/dev/null || echo "")

    if [ -z "$queue_url" ]; then
        print_status "failed" "Lab Failed: Queue '$QUEUE_NAME' not found."
        exit 1
    fi

    policy=$(aws sqs get-queue-attributes --queue-url "$queue_url" --attribute-names Policy --region "$REGION" --query "Attributes.Policy" --output text 2>/dev/null || echo "")

    if [ -z "$policy" ] || [ "$policy" == "None" ]; then
        print_status "failed" "Lab Failed: No resource policy found on '$QUEUE_NAME'."
        exit 1
    fi

    if ! echo "$policy" | grep -q "sns.amazonaws.com"; then
        print_status "failed" "Lab Failed: Queue policy does not grant permissions to SNS."
        exit 1
    fi

    if ! echo "$policy" | grep -q "$topic_arn"; then
        print_status "failed" "Lab Failed: Queue policy does not reference the SNS topic ARN '$topic_arn'."
        exit 1
    fi

    print_status "success" "Lab Passed: Queue policy correctly grants SNS permission to send messages."
}

function test_sns_topic_is_standard() {
    local topic_arn topic_type

    topic_arn="arn:aws:sns:${REGION}:${ACCOUNT_ID}:${TOPIC_NAME}"
    topic_type=$(aws sns get-topic-attributes --topic-arn "$topic_arn" --region "$REGION" --query "Attributes.FifoTopic" --output text 2>/dev/null || echo "")

    if [ "$topic_type" == "true" ]; then
        print_status "failed" "Lab Failed: SNS topic '$TOPIC_NAME' is FIFO. It must be a standard topic to work with standard SQS queues."
        exit 1
    fi

    if [ "$topic_type" != "false" ] && [ -n "$topic_type" ]; then
        print_status "failed" "Lab Failed: Could not determine SNS topic type."
        exit 1
    fi

    print_status "success" "Lab Passed: SNS topic '$TOPIC_NAME' is a standard (non-FIFO) topic."
}

function test_sqs_queue_is_standard() {
    local queue_url queue_attributes is_fifo

    queue_url=$(aws sqs get-queue-url --queue-name "$QUEUE_NAME" --region "$REGION" --query "QueueUrl" --output text 2>/dev/null || echo "")

    if [ -z "$queue_url" ]; then
        print_status "failed" "Lab Failed: Queue '$QUEUE_NAME' not found."
        exit 1
    fi

    is_fifo=$(aws sqs get-queue-attributes --queue-url "$queue_url" --attribute-names All --region "$REGION" --query "Attributes.FifoQueue" --output text 2>/dev/null || echo "")

    if [ "$is_fifo" == "true" ]; then
        print_status "failed" "Lab Failed: SQS queue '$QUEUE_NAME' is FIFO. It must be a standard queue to work with standard SNS topics."
        exit 1
    fi

    if [ "$is_fifo" != "false" ] && [ -n "$is_fifo" ]; then
        print_status "failed" "Lab Failed: Could not determine SQS queue type."
        exit 1
    fi

    print_status "success" "Lab Passed: SQS queue '$QUEUE_NAME' is a standard (non-FIFO) queue."
}

function test_subscription_via_publish() {
    local queue_url msg_body topic_arn

    topic_arn="arn:aws:sns:${REGION}:${ACCOUNT_ID}:${TOPIC_NAME}"
    queue_url=$(aws sqs get-queue-url --queue-name "$QUEUE_NAME" --region "$REGION" --query "QueueUrl" --output text 2>/dev/null || echo "")

    # Publish a probe message
    aws sns publish --topic-arn "$topic_arn" --message '{"event_type":"sub_check","delivery_id":"D-CHECK-01"}' --region "$REGION" > /dev/null 2>&1

    sleep 3

    # Try to receive it from the queue
    msg_body=$(aws sqs receive-message --queue-url "$queue_url" --region "$REGION" --query "Messages[0].Body" --output text 2>/dev/null || echo "")

    if [ -z "$msg_body" ] || [ "$msg_body" == "None" ]; then
        print_status "failed" "Lab Failed: Message published to SNS did not arrive in '$QUEUE_NAME'."
        exit 1
    fi

    print_status "success" "Lab Passed: SNS subscription verified — message published to SNS arrived in the SQS queue."
}

test_sns_topic_exists
test_sns_topic_is_standard
test_sqs_queue_is_standard
test_queue_policy_allows_sns
test_subscription_via_publish

print_status "success" "Lab Passed: SNS topic exists, queue policy is correct, and SNS-to-SQS delivery is working."
exit 0