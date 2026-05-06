#!/bin/bash

set -euo pipefail

# ==========================================
# SOLUTION SCRIPT: EC2 with EBS Volume Lab
# ==========================================

echo "================================================"
echo "EC2 with EBS Volume Lab - Solution"
echo "================================================"
echo ""

REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Load environment variables if available
if [ -f /tmp/ec2_ebs_lab_env.txt ]; then
    echo "Loading environment variables from /tmp/ec2_ebs_lab_env.txt..."
    source /tmp/ec2_ebs_lab_env.txt
    echo "Environment variables loaded successfully"
else
    echo "Error: /tmp/ec2_ebs_lab_env.txt not found"
    echo "Please run the setup script first"
    exit 1
fi

echo ""
echo "Configuration:"
echo "  Account ID: $ACCOUNT_ID"
echo "  Region: $REGION"
echo "  VPC: $VPC_ID"
echo "  Subnet: $SUBNET_ID"
echo "  AZ: $AZ"
echo "  AMI: $AMI_ID"
echo "  Key: $KEY_NAME"
echo ""

# ==========================================
# STEP 1: Get Your Public IP
# ==========================================
echo "================================================"
echo "Step 1: Getting Your Public IP"
echo "================================================"
echo ""

MY_IP=$(curl -s ifconfig.me)
echo "Your public IP: $MY_IP"
echo ""

# ==========================================
# STEP 2: Create Security Group
# ==========================================
echo "================================================"
echo "Step 2: Creating Security Group"
echo "================================================"
echo ""

SG_NAME="file-server-sg"

echo "Creating security group: $SG_NAME"

set +e
SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "Security group for file server" \
    --vpc-id "$VPC_ID" \
    --region "$REGION" \
    --query 'GroupId' \
    --output text 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "[SUCCESS] Security group created: $SG_ID"
else
    # Get existing security group
    SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" \
        --region "$REGION" \
        --query 'SecurityGroups[0].GroupId' \
        --output text)
    echo "[INFO] Using existing security group: $SG_ID"
fi
set -e

echo ""
echo "Adding security group rules..."

# Add SSH rule from your IP
set +e
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "${MY_IP}/32" \
    --region "$REGION" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "[SUCCESS] SSH rule added from $MY_IP"
else
    echo "[INFO] SSH rule already exists"
fi
set -e

# Add self-referencing rule
set +e
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol -1 \
    --source-group "$SG_ID" \
    --region "$REGION" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "[SUCCESS] Self-referencing rule added"
else
    echo "[INFO] Self-referencing rule already exists"
fi
set -e

echo ""

# ==========================================
# STEP 3: Launch EC2 Instance
# ==========================================
echo "================================================"
echo "Step 3: Launching EC2 Instance"
echo "================================================"
echo ""

INSTANCE_NAME="file-server-01"

echo "Launching instance: $INSTANCE_NAME"

# Check if instance already exists
EXISTING_INSTANCE=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,stopped,pending" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_INSTANCE" ] && [ "$EXISTING_INSTANCE" != "None" ]; then
    echo "[INFO] Instance already exists: $EXISTING_INSTANCE"
    INSTANCE_ID="$EXISTING_INSTANCE"
else
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type t2.micro \
        --key-name "$KEY_NAME" \
        --security-group-ids "$SG_ID" \
        --subnet-id "$SUBNET_ID" \
        --iam-instance-profile Arn="$INSTANCE_PROFILE_ARN" \
        --associate-public-ip-address \
        --tag-specifications \
            "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Environment,Value=Development},{Key=Application,Value=FileServer}]" \
        --region "$REGION" \
        --query 'Instances[0].InstanceId' \
        --output text)
    
    echo "[SUCCESS] Instance launched: $INSTANCE_ID"
fi

echo ""
echo "Waiting for instance to be running..."

aws ec2 wait instance-running \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION"

echo "[SUCCESS] Instance is running"

# Get instance public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "Instance Public IP: $PUBLIC_IP"

echo ""

# ==========================================
# STEP 4: Create EBS Volume
# ==========================================
echo "================================================"
echo "Step 4: Creating EBS Volume"
echo "================================================"
echo ""

VOLUME_NAME="file-server-data"

echo "Creating EBS volume: $VOLUME_NAME"

# Check if volume already exists
EXISTING_VOLUME=$(aws ec2 describe-volumes \
    --filters "Name=tag:Name,Values=$VOLUME_NAME" "Name=status,Values=available,in-use" \
    --region "$REGION" \
    --query 'Volumes[0].VolumeId' \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_VOLUME" ] && [ "$EXISTING_VOLUME" != "None" ]; then
    echo "[INFO] Volume already exists: $EXISTING_VOLUME"
    VOLUME_ID="$EXISTING_VOLUME"
else
    VOLUME_ID=$(aws ec2 create-volume \
        --volume-type gp3 \
        --size 10 \
        --availability-zone "$AZ" \
        --encrypted \
        --tag-specifications \
            "ResourceType=volume,Tags=[{Key=Name,Value=$VOLUME_NAME},{Key=Purpose,Value=DataStorage}]" \
        --region "$REGION" \
        --query 'VolumeId' \
        --output text)
    
    echo "[SUCCESS] Volume created: $VOLUME_ID"
fi

echo ""
echo "Waiting for volume to be available..."

aws ec2 wait volume-available \
    --volume-ids "$VOLUME_ID" \
    --region "$REGION"

echo "[SUCCESS] Volume is available"

echo ""

# ==========================================
# STEP 5: Attach Volume to Instance
# ==========================================
echo "================================================"
echo "Step 5: Attaching Volume to Instance"
echo "================================================"
echo ""

echo "Attaching volume $VOLUME_ID to instance $INSTANCE_ID..."

# Check if already attached
ATTACHMENT_STATE=$(aws ec2 describe-volumes \
    --volume-ids "$VOLUME_ID" \
    --region "$REGION" \
    --query 'Volumes[0].Attachments[0].State' \
    --output text 2>/dev/null || echo "")

if [ "$ATTACHMENT_STATE" == "attached" ]; then
    echo "[INFO] Volume already attached"
else
    aws ec2 attach-volume \
        --volume-id "$VOLUME_ID" \
        --instance-id "$INSTANCE_ID" \
        --device /dev/sdf \
        --region "$REGION" >/dev/null
    
    echo "[SUCCESS] Volume attachment initiated"
    echo "Waiting for attachment to complete..."
    sleep 15
fi

# Verify attachment
ATTACHMENT_STATE=$(aws ec2 describe-volumes \
    --volume-ids "$VOLUME_ID" \
    --region "$REGION" \
    --query 'Volumes[0].Attachments[0].State' \
    --output text)

echo "Attachment state: $ATTACHMENT_STATE"

echo ""

# ==========================================
# STEP 6: Format and Mount Volume
# ==========================================
echo "================================================"
echo "Step 6: Format and Mount Volume Instructions"
echo "================================================"
echo ""

echo "To complete the lab, SSH into the instance and run these commands:"
echo ""
echo "SSH Command:"
echo "  ssh -i $KEY_PATH ec2-user@$PUBLIC_IP"
echo ""
echo "Once connected, run:"
echo ""
echo "# List block devices"
echo "lsblk"
echo ""
echo "# Format volume (only if not already formatted)"
echo "sudo mkfs -t ext4 /dev/xvdf"
echo ""
echo "# Create mount point"
echo "sudo mkdir -p /data"
echo ""
echo "# Mount volume"
echo "sudo mount /dev/xvdf /data"
echo ""
echo "# Change ownership"
echo "sudo chown ec2-user:ec2-user /data"
echo ""
echo "# Create test file"
echo "echo 'This is test data on EBS volume' > /data/test.txt"
echo ""
echo "# Verify"
echo "cat /data/test.txt"
echo "df -h /data"
echo ""
echo "# Optional: Configure auto-mount on reboot"
echo "echo '/dev/xvdf /data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab"
echo ""

# ==========================================
# Summary
# ==========================================
echo "================================================"
echo "Deployment Summary"
echo "================================================"
echo ""
echo "Resources created:"
echo "  [DONE] Security Group: $SG_ID"
echo "  [DONE] EC2 Instance: $INSTANCE_ID"
echo "  [DONE] EBS Volume: $VOLUME_ID"
echo "  [DONE] Volume Attachment: attached as /dev/sdf"
echo ""
echo "Instance Details:"
echo "  - Name: $INSTANCE_NAME"
echo "  - Type: t2.micro"
echo "  - Public IP: $PUBLIC_IP"
echo "  - SSH Key: $KEY_NAME"
echo ""
echo "Volume Details:"
echo "  - Name: $VOLUME_NAME"
echo "  - Size: 10 GB"
echo "  - Type: gp3"
echo "  - Encrypted: Yes"
echo "  - Device: /dev/sdf"
echo ""
echo "Next steps:"
echo "  1. SSH into instance: ssh -i $KEY_PATH ec2-user@$PUBLIC_IP"
echo "  2. Format and mount the volume (see commands above)"
echo "  3. Create test file in /data"
echo "  4. Verify with: df -h /data && cat /data/test.txt"
echo ""
echo "================================================"