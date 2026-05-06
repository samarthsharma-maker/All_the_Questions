#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
LAB_DIR="/home/user/craftify-cw-lab"
KEY_NAME="craftify-cw-key"
KEY_PATH="$LAB_DIR/${KEY_NAME}.pem"
SNS_TOPIC_NAME="craftify-alerts"
SQS_QUEUE_NAME="craftify-alerts-queue"

mkdir -p "$LAB_DIR"

echo "Installing dependencies..."
apt-get install -y jq > /dev/null 2>&1 || yum install -y jq > /dev/null 2>&1

# Get default VPC and subnet
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text --region "$REGION")

SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=defaultForAz,Values=true" \
    --query "Subnets[?AvailabilityZone!='us-west-2d'] | [0].SubnetId" \
    --output text --region "$REGION")

# Create key pair — idempotent
echo "Creating key pair..."
if [ ! -f "$KEY_PATH" ]; then
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --query "KeyMaterial" \
        --output text \
        --region "$REGION" > "$KEY_PATH"
    chmod 400 "$KEY_PATH"
else
    echo "Key pair already exists. Skipping."
fi

# Create security group — idempotent
echo "Creating security group..."
EC2_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=craftify-cw-sg" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" \
    --output text --region "$REGION" 2>/dev/null || echo "")

if [ -z "$EC2_SG_ID" ] || [ "$EC2_SG_ID" == "None" ]; then
    EC2_SG_ID=$(aws ec2 create-security-group \
        --group-name "craftify-cw-sg" \
        --description "Craftify CloudWatch lab security group" \
        --vpc-id "$VPC_ID" \
        --query "GroupId" \
        --output text --region "$REGION")
    aws ec2 authorize-security-group-ingress \
        --group-id "$EC2_SG_ID" \
        --protocol tcp --port 22 \
        --cidr "0.0.0.0/0" \
        --region "$REGION" > /dev/null
fi

# Create IAM role for EC2 with CloudWatch permissions
echo "Creating IAM role..."
aws iam get-role --role-name "craftify-cw-ec2-role" > /dev/null 2>&1 || \
aws iam create-role \
    --role-name "craftify-cw-ec2-role" \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' > /dev/null

aws iam attach-role-policy \
    --role-name "craftify-cw-ec2-role" \
    --policy-arn "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" 2>/dev/null || true

aws iam attach-role-policy \
    --role-name "craftify-cw-ec2-role" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" 2>/dev/null || true

aws iam create-instance-profile \
    --instance-profile-name "craftify-cw-ec2-profile" > /dev/null 2>&1 || true

aws iam add-role-to-instance-profile \
    --instance-profile-name "craftify-cw-ec2-profile" \
    --role-name "craftify-cw-ec2-role" 2>/dev/null || true

echo "Waiting for IAM propagation..."
sleep 15

# Create SNS topic
echo "Creating SNS topic..."
SNS_ARN=$(aws sns create-topic \
    --name "$SNS_TOPIC_NAME" \
    --region "$REGION" \
    --query "TopicArn" \
    --output text)

# Create SQS queue for SNS subscription verification
echo "Creating SQS queue..."
SQS_URL=$(aws sqs create-queue \
    --queue-name "$SQS_QUEUE_NAME" \
    --region "$REGION" \
    --query "QueueUrl" \
    --output text)

SQS_ARN=$(aws sqs get-queue-attributes \
    --queue-url "$SQS_URL" \
    --attribute-names QueueArn \
    --region "$REGION" \
    --query "Attributes.QueueArn" \
    --output text)

# Apply SQS policy to allow SNS
cat > /tmp/sqs-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "sns.amazonaws.com"},
    "Action": "sqs:SendMessage",
    "Resource": "${SQS_ARN}",
    "Condition": {"ArnEquals": {"aws:SourceArn": "${SNS_ARN}"}}
  }]
}
EOF

cat > /tmp/sqs-attributes.json << EOF
{
  "Policy": $(cat /tmp/sqs-policy.json | jq -c . | jq -R .)
}
EOF

aws sqs set-queue-attributes \
    --queue-url "$SQS_URL" \
    --attributes file:///tmp/sqs-attributes.json \
    --region "$REGION"

# Subscribe SQS to SNS
aws sns subscribe \
    --topic-arn "$SNS_ARN" \
    --protocol sqs \
    --notification-endpoint "$SQS_ARN" \
    --region "$REGION" > /dev/null

# Get latest Amazon Linux 2 AMI
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text --region "$REGION")

# User data — install CW agent, set up app log, start generating log entries
USER_DATA=$(cat << 'EOF'
#!/bin/bash
yum update -y
yum install -y amazon-cloudwatch-agent python3

mkdir -p /var/log/craftify

# Simple app that continuously writes logs
cat > /home/ec2-user/craftify_app.py << 'PYEOF'
import time
import random
import datetime

log_file = "/var/log/craftify/app.log"

while True:
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    level = random.choice(["INFO", "INFO", "INFO", "INFO", "DEBUG"])
    msg = random.choice([
        "Course enrollment processed",
        "User session started",
        "Payment gateway response received",
        "Content delivery request handled"
    ])
    with open(log_file, "a") as f:
        f.write(f"[{ts}] {level}: {msg}\n")
    time.sleep(5)
PYEOF

chmod +x /home/ec2-user/craftify_app.py
chown ec2-user:ec2-user /home/ec2-user/craftify_app.py

# Run the app in background
nohup python3 /home/ec2-user/craftify_app.py > /dev/null 2>&1 &

# CloudWatch agent is installed but NOT configured or started (intentional)
EOF
)

# Launch EC2 — idempotent
echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=craftify-app-server-cw" "Name=instance-state-name,Values=running,pending" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text --region "$REGION" 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type t2.micro \
        --key-name "$KEY_NAME" \
        --security-group-ids "$EC2_SG_ID" \
        --subnet-id "$SUBNET_ID" \
        --associate-public-ip-address \
        --iam-instance-profile Name="craftify-cw-ec2-profile" \
        --user-data "$USER_DATA" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=craftify-app-server-cw}]" \
        --query "Instances[0].InstanceId" \
        --output text --region "$REGION")
    echo "EC2 launched: $INSTANCE_ID"
else
    echo "EC2 already exists: $INSTANCE_ID"
fi

aws ec2 wait instance-running \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION"

INSTANCE_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text --region "$REGION")

# Save config
cat > "$LAB_DIR/lab-config.txt" << EOF
INSTANCE_ID=$INSTANCE_ID
INSTANCE_IP=$INSTANCE_IP
KEY_PATH=$KEY_PATH
SNS_ARN=$SNS_ARN
SQS_URL=$SQS_URL
SQS_ARN=$SQS_ARN
SNS_TOPIC_NAME=$SNS_TOPIC_NAME
SQS_QUEUE_NAME=$SQS_QUEUE_NAME
REGION=$REGION
LOG_GROUP=/craftify/app-logs
METRIC_FILTER_NAME=craftify-error-count
ALARM_NAME=craftify-error-alarm
EOF

chown -R user:user "$LAB_DIR"

echo ""
echo "========================================="
echo "  Craftify CloudWatch Lab Ready"
echo "========================================="
echo ""
echo "Instance IP  : $INSTANCE_IP"
echo "SSH key      : $KEY_PATH"
echo "SNS topic    : $SNS_TOPIC_NAME"
echo "SQS queue    : $SQS_QUEUE_NAME"
echo ""
echo "SSH command  : ssh -i $KEY_PATH ec2-user@$INSTANCE_IP"
echo ""
echo "Note: Wait 2-3 minutes before SSHing in."
echo ""