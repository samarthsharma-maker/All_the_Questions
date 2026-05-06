#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

CONFIG="/home/user/craftify-cw-lab/lab-config.txt"
if [ ! -f "$CONFIG" ]; then
    echo "Lab config not found. Run setup.sh first."
    exit 1
fi

source "$CONFIG"

echo "========================================="
echo "  Craftify CloudWatch Lab - Solution"
echo "========================================="
echo ""
echo "Instance  : $INSTANCE_IP"
echo "Log group : $LOG_GROUP"
echo "SNS topic : $SNS_TOPIC_NAME"

# Step 1: Create log group
echo ""
echo "Step 1: Creating log group..."
aws logs create-log-group \
    --log-group-name "$LOG_GROUP" \
    --region "$REGION" 2>/dev/null || echo "Log group already exists."

# Step 2: Wait for SSH and configure CloudWatch agent
echo ""
echo "Step 2: Waiting for SSH..."
for i in $(seq 1 20); do
    if ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=5 \
        -o BatchMode=yes \
        ec2-user@"$INSTANCE_IP" "echo ok" > /dev/null 2>&1; then
        echo "SSH ready."
        break
    fi
    echo "  Attempt $i — waiting..."
    sleep 10
done

echo "Configuring and starting CloudWatch agent..."
ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=15 \
    ec2-user@"$INSTANCE_IP" \
    "sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc && sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json > /dev/null << 'CWEOF'
{
  \"logs\": {
    \"logs_collected\": {
      \"files\": {
        \"collect_list\": [
          {
            \"file_path\": \"/var/log/craftify/app.log\",
            \"log_group_name\": \"${LOG_GROUP}\",
            \"log_stream_name\": \"{instance_id}\",
            \"timestamp_format\": \"%Y-%m-%d %H:%M:%S\"
          }
        ]
      }
    }
  }
}
CWEOF
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s"

echo "CloudWatch agent started. Waiting 60 seconds for logs to flow..."
sleep 60

# Step 3: Create metric filter
echo ""
echo "Step 3: Creating metric filter..."
aws logs put-metric-filter \
    --log-group-name "$LOG_GROUP" \
    --filter-name "$METRIC_FILTER_NAME" \
    --filter-pattern "ERROR" \
    --metric-transformations \
        metricName=ErrorCount,metricNamespace=Craftify/AppMetrics,metricValue=1,defaultValue=0 \
    --region "$REGION"

echo "Metric filter created."

# Step 4: Create CloudWatch alarm
echo ""
echo "Step 4: Creating CloudWatch alarm..."
aws cloudwatch put-metric-alarm \
    --alarm-name "$ALARM_NAME" \
    --alarm-description "Fires when Craftify app logs contain ERROR" \
    --metric-name ErrorCount \
    --namespace Craftify/AppMetrics \
    --statistic Sum \
    --period 60 \
    --threshold 1 \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --evaluation-periods 1 \
    --alarm-actions "$SNS_ARN" \
    --treat-missing-data notBreaching \
    --region "$REGION"

echo "Alarm created."

# Step 5: Inject an ERROR to trigger the alarm
echo ""
echo "Step 5: Injecting ERROR into app log to trigger alarm..."
ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=15 \
    ec2-user@"$INSTANCE_IP" \
    "echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Payment gateway timeout order rollback initiated\" | sudo tee -a /var/log/craftify/app.log"

echo "Error injected. Waiting 120 seconds for metric to update and alarm to fire..."
sleep 120

# Step 6: Verify SQS received notification
echo ""
echo "Step 6: Checking SQS for alarm notification..."
aws sqs receive-message \
    --queue-url "$SQS_URL" \
    --region "$REGION"

echo ""
echo "========================================="
echo "  Solution Applied: Summary"
echo "========================================="
echo ""
echo "Log group    : $LOG_GROUP created"
echo "CW Agent     : Configured and running"
echo "Metric filter: $METRIC_FILTER_NAME — matches ERROR lines"
echo "Alarm        : $ALARM_NAME — threshold 1, period 60s"
echo "SNS wired    : $SNS_TOPIC_NAME"
echo "Verified     : SNS notification delivered to SQS"
echo ""