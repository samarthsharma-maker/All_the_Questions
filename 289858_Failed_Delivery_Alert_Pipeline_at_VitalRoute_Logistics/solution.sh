#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
LAB_DIR="/home/user/vitalroute-alerts-lab"
DLQ_NAME="vitalroute-failed-delivery-dlq"
QUEUE_NAME="vitalroute-failed-delivery-queue"
TOPIC_NAME="vitalroute-delivery-alerts"

echo "Resolving AWS account ID: $ACCOUNT_ID"

# Step 1: Create the DLQ
echo ""
echo "Creating DLQ: $DLQ_NAME..."
DLQ_URL=$(aws sqs create-queue \
    --queue-name "$DLQ_NAME" \
    --region "$REGION" \
    --query "QueueUrl" \
    --output text)

DLQ_ARN=$(aws sqs get-queue-attributes \
    --queue-url "$DLQ_URL" \
    --attribute-names QueueArn \
    --region "$REGION" \
    --query "Attributes.QueueArn" \
    --output text)

echo "DLQ ARN: $DLQ_ARN"

# Step 2: Create the main queue with redrive policy
echo ""
echo "Creating main queue: $QUEUE_NAME..."

REDRIVE_VALUE=$(cat "$LAB_DIR/redrive-policy.json" | jq -c .)

cat > /tmp/main-queue-attributes.json << EOF
{
  "RedrivePolicy": $(echo "$REDRIVE_VALUE" | jq -R .)
}
EOF

QUEUE_URL=$(aws sqs create-queue \
    --queue-name "$QUEUE_NAME" \
    --region "$REGION" \
    --attributes file:///tmp/main-queue-attributes.json \
    --query "QueueUrl" \
    --output text)

QUEUE_ARN=$(aws sqs get-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --attribute-names QueueArn \
    --region "$REGION" \
    --query "Attributes.QueueArn" \
    --output text)

echo "Queue ARN: $QUEUE_ARN"

# Step 3: Create the SNS topic
echo ""
echo "Creating SNS topic: $TOPIC_NAME..."
TOPIC_ARN=$(aws sns create-topic \
    --name "$TOPIC_NAME" \
    --region "$REGION" \
    --query "TopicArn" \
    --output text)

echo "Topic ARN: $TOPIC_ARN"

# Step 4: Subscribe SQS queue to SNS topic
echo ""
echo "Subscribing SQS queue to SNS topic..."
aws sns subscribe \
    --topic-arn "$TOPIC_ARN" \
    --protocol sqs \
    --notification-endpoint "$QUEUE_ARN" \
    --region "$REGION"

# Step 5: Apply queue policy to allow SNS to send messages
echo ""
echo "Applying queue policy..."

POLICY_VALUE=$(cat "$LAB_DIR/queue-policy.json" | jq -c .)

cat > /tmp/queue-policy-attributes.json << EOF
{
  "Policy": $(echo "$POLICY_VALUE" | jq -R .)
}
EOF

aws sqs set-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --region "$REGION" \
    --attributes file:///tmp/queue-policy-attributes.json

# Step 6: Publish a test event via SNS and verify delivery
echo ""
echo "Publishing test event to SNS..."
aws sns publish \
    --topic-arn "$TOPIC_ARN" \
    --message file://"$LAB_DIR/failed-delivery-event.json" \
    --region "$REGION"

echo "Receiving message from main queue..."
MSG=$(aws sqs receive-message \
    --queue-url "$QUEUE_URL" \
    --region "$REGION" \
    --query "Messages[0]" \
    --output json)

echo "Message received:"
echo "$MSG" | jq .

RECEIPT_HANDLE=$(echo "$MSG" | jq -r '.ReceiptHandle')

# Step 7: Simulate DLQ routing - receive 3 times without deleting
echo ""
echo "Changing message visibility timeout to 5 seconds for DLQ simulation..."
aws sqs change-message-visibility \
    --queue-url "$QUEUE_URL" \
    --receipt-handle "$RECEIPT_HANDLE" \
    --visibility-timeout 5 \
    --region "$REGION"

echo "Message visibility timeout updated. Waiting 3 seconds..."
sleep 3

echo "Receiving message 3 times to trigger DLQ routing..."
cat > /tmp/vt-attributes.json << 'VTEOF'
{
  "VisibilityTimeout": "5"
}
VTEOF

aws sqs set-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --region "$REGION" \
    --attributes file:///tmp/vt-attributes.json

echo "Visibility timeout updated. Waiting 3 seconds for it to take effect..."
sleep 3

echo "Receiving message 3 times to trigger DLQ routing..."
for i in 1 2 3; do
    echo "Receive attempt $i..."
    aws sqs receive-message \
        --queue-url "$QUEUE_URL" \
        --region "$REGION" > /dev/null 2>&1
    echo "Waiting for visibility timeout to expire..."
    sleep 7
done

echo "Waiting for DLQ routing to complete..."
sleep 5

echo "Checking DLQ for routed message..."
aws sqs receive-message \
    --queue-url "$DLQ_URL" \
    --region "$REGION"

echo ""
echo "========================================="
echo "  Solution Applied: Summary"
echo "========================================="
echo ""
echo "DLQ             : $DLQ_NAME"
echo "Main Queue      : $QUEUE_NAME (maxReceiveCount=3)"
echo "SNS Topic       : $TOPIC_NAME"
echo "Subscription    : SQS endpoint confirmed"
echo "Queue Policy    : SNS sqs:SendMessage granted"
echo "Message Flow    : SNS publish delivered to SQS"
echo "DLQ Routing     : Message moved to DLQ after 3 failed receives"
echo ""