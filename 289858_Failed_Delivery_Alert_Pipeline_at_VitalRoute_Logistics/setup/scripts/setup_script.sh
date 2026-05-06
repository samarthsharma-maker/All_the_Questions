#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
LAB_DIR="/home/user/vitalroute-alerts-lab"

mkdir -p "$LAB_DIR"

echo "Installing jq..."
apt update
apt-get install -y jq > /dev/null 2>&1 || yum install -y jq > /dev/null 2>&1

# Write queue policy document
cat > "$LAB_DIR/queue-policy.json" << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSNSPublish",
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:${REGION}:${ACCOUNT_ID}:vitalroute-failed-delivery-queue",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:sns:${REGION}:${ACCOUNT_ID}:vitalroute-delivery-alerts"
        }
      }
    }
  ]
}
EOF

# Write DLQ redrive policy document
cat > "$LAB_DIR/redrive-policy.json" << EOF
{
  "deadLetterTargetArn": "arn:aws:sqs:${REGION}:${ACCOUNT_ID}:vitalroute-failed-delivery-dlq",
  "maxReceiveCount": 3
}
EOF

# Write sample event payload
cat > "$LAB_DIR/failed-delivery-event.json" << 'EOF'
{
  "event_type": "delivery_failed",
  "delivery_id": "D-7821",
  "driver_id": "DRV-9921",
  "city": "Bengaluru",
  "reason": "customer_unavailable",
  "timestamp": "2024-04-01T14:32:00Z"
}
EOF

chown -R user:user "$LAB_DIR"

echo ""
echo "========================================="
echo "  VitalRoute Alerts Lab Environment Ready"
echo "========================================="
echo ""
echo "Lab directory  : $LAB_DIR"
echo "AWS Account ID : $ACCOUNT_ID"
echo "Region         : $REGION"
echo ""
echo "Resource names to use:"
echo "  DLQ name       : vitalroute-failed-delivery-dlq"
echo "  Queue name     : vitalroute-failed-delivery-queue"
echo "  SNS topic name : vitalroute-delivery-alerts"
echo ""
echo "Policy documents available in $LAB_DIR:"
echo "  queue-policy.json       -- SQS policy allowing SNS to send messages"
echo "  redrive-policy.json     -- DLQ redrive policy with maxReceiveCount=3"
echo "  failed-delivery-event.json -- Sample event payload to publish via SNS"
echo ""
echo "Getting started:"
echo "  1. Create the DLQ first"
echo "  2. Create the main queue and wire the DLQ using redrive-policy.json"
echo "  3. Create the SNS topic"
echo "  4. Subscribe the SQS queue to the SNS topic"
echo "  5. Apply queue-policy.json to allow SNS to deliver messages"
echo "  6. Publish a test event and verify it lands in the queue"
echo "  7. Simulate DLQ routing by receiving the message 3 times without deleting it"
echo ""
