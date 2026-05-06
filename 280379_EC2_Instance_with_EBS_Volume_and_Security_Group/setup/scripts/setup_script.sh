#!/bin/bash

set -euo pipefail

# ==========================================
# SETUP SCRIPT: EC2 with EBS Volume Lab
# ==========================================

REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Setting up resources in region: ${REGION}"
echo "Account ID: ${ACCOUNT_ID}"
echo ""

echo "[1/5] Getting VPC information..."

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --region "$REGION" --query 'Vpcs[0].VpcId' --output text)
if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "Error: No default VPC found"
    exit 1
fi

SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --region "$REGION" --query 'Subnets[0].SubnetId' --output text)

AZ=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_ID" --region "$REGION" --query 'Subnets[0].AvailabilityZone' --output text)

echo "[2/5] Getting latest Amazon Linux 2023 AMI..."

AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" --region "$REGION" --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)

echo "  AMI ID: $AMI_ID"
echo "[3/5] Creating SSH key pair..."

KEY_NAME="ec2-lab-key-${ACCOUNT_ID}"

aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION" 2>/dev/null || true
aws ec2 create-key-pair --key-name "$KEY_NAME" --region "$REGION" --query 'KeyMaterial' --output text > /tmp/${KEY_NAME}.pem
chmod 400 /tmp/${KEY_NAME}.pem

echo "[4/5] Creating IAM role for EC2..."

cat > /tmp/ec2-trust-policy.json <<'TRUST'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
TRUST

# Create role
aws iam create-role --role-name EC2-SSM-Role --assume-role-policy-document file:///tmp/ec2-trust-policy.json --description "Allows EC2 instances to use Systems Manager" 2>/dev/null || echo "  Role already exists"
aws iam attach-role-policy --role-name EC2-SSM-Role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore 2>/dev/null || echo "  Policy already attached"
aws iam create-instance-profile --instance-profile-name EC2-SSM-InstanceProfile 2>/dev/null || echo "  Instance profile already exists"
aws iam add-role-to-instance-profile --instance-profile-name EC2-SSM-InstanceProfile --role-name EC2-SSM-Role 2>/dev/null || echo "  Role already in instance profile"

echo "  Waiting for IAM role to propagate..."
sleep 10

INSTANCE_PROFILE_ARN="arn:aws:iam::${ACCOUNT_ID}:instance-profile/EC2-SSM-InstanceProfile"

cat > /tmp/ec2_ebs_lab_env.txt <<ENV
# EC2 with EBS Volume Lab Environment Variables
# Source this file: source /tmp/ec2_ebs_lab_env.txt

REGION=$REGION
ACCOUNT_ID=$ACCOUNT_ID
VPC_ID=$VPC_ID
SUBNET_ID=$SUBNET_ID
AZ=$AZ
AMI_ID=$AMI_ID
KEY_NAME=$KEY_NAME
KEY_PATH=/tmp/${KEY_NAME}.pem
INSTANCE_PROFILE_ARN=$INSTANCE_PROFILE_ARN
ENV

echo ""
echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo ""
echo "Resources created:"
echo "  VPC: $VPC_ID"
echo "  Subnet: $SUBNET_ID"
echo "  Availability Zone: $AZ"
echo "  AMI: $AMI_ID"
echo "  Key Pair: $KEY_NAME"
echo "  IAM Role: EC2-SSM-Role"
echo ""
echo "Environment variables saved to: /tmp/ec2_ebs_lab_env.txt"

# Cleanup
rm -f /tmp/ec2-trust-policy.json