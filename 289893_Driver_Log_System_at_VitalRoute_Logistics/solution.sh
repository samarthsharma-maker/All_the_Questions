#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

REGION="us-west-2"
LAB_DIR="/home/user/vitalroute-efs-lab"
CONFIG="$LAB_DIR/lab-config.txt"

if [ ! -f "$CONFIG" ]; then
    echo "Lab config not found. Run setup.sh first."
    exit 1
fi

source "$CONFIG"

echo "========================================="
echo "  VitalRoute EFS Lab - Solution"
echo "========================================="
echo ""
echo "EFS DNS  : $EFS_DNS"
echo "Server-1 : $IP_1"
echo "Server-2 : $IP_2"

# Fix 1: Update EFS security group - idempotent
echo ""
echo "Fix 1: Updating EFS security group..."

CIDR_EXISTS=$(aws ec2 describe-security-groups \
    --group-ids "$EFS_SG_ID" \
    --region "$REGION" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`2049\`].IpRanges[*].CidrIp" \
    --output text 2>/dev/null || echo "")

if [ -n "$CIDR_EXISTS" ] && [ "$CIDR_EXISTS" != "None" ]; then
    echo "Removing VPC CIDR rule..."
    aws ec2 revoke-security-group-ingress \
        --group-id "$EFS_SG_ID" \
        --protocol tcp \
        --port 2049 \
        --cidr "$VPC_CIDR" \
        --region "$REGION"
    echo "VPC CIDR rule removed."
else
    echo "VPC CIDR rule already removed. Skipping."
fi

SG_EXISTS=$(aws ec2 describe-security-groups \
    --group-ids "$EFS_SG_ID" \
    --region "$REGION" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`2049\`].UserIdGroupPairs[*].GroupId" \
    --output text 2>/dev/null || echo "")

if [ -z "$SG_EXISTS" ] || [ "$SG_EXISTS" == "None" ]; then
    echo "Adding EC2 SG rule..."
    aws ec2 authorize-security-group-ingress \
        --group-id "$EFS_SG_ID" \
        --protocol tcp \
        --port 2049 \
        --source-group "$EC2_SG_ID" \
        --region "$REGION"
    echo "EC2 SG rule added."
else
    echo "EC2 SG rule already exists. Skipping."
fi

sleep 5

# Fix 2: Mount EFS on server-1 - idempotent
echo ""
echo "Fix 2: Mounting EFS on server-1..."
ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=15 \
    ec2-user@"$IP_1" \
    "
    if df -h | grep -q '/mnt/efs'; then
        echo 'EFS already mounted on server-1. Skipping.'
    else
        sudo mount -a > /dev/null 2>&1 && echo 'EFS mounted successfully.'
    fi
    df -h | grep '/mnt/efs' || echo 'Mount check: not visible in df yet.'
    "

# Write test file from server-1 - idempotent
echo ""
echo "Writing test file from server-1..."
ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=15 \
    ec2-user@"$IP_1" \
    "echo 'driver DRV-9921 completed delivery D-1001 at \$(date)' | sudo tee /mnt/efs/driver.log"

# Fix 3: Add fstab entry and mount EFS on server-2 - idempotent
echo ""
echo "Fix 3: Configuring EFS on server-2..."
ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=15 \
    ec2-user@"$IP_2" << SSHEOF
    if df -h | grep -q '/mnt/efs'; then
        echo 'EFS already mounted on server-2. Skipping mount.'
    else
        if grep -q '/mnt/efs' /etc/fstab; then
            echo 'fstab entry already exists.'
        else
            echo '${EFS_DNS}:/ /mnt/efs efs defaults,_netdev 0 0' | sudo tee -a /etc/fstab
            echo 'fstab entry added.'
        fi
        sudo mount -a > /dev/null 2>&1 && echo 'EFS mounted successfully on server-2.'
    fi
    df -h | grep '/mnt/efs' || echo 'Mount check: not visible in df yet.'
SSHEOF

# Verify shared file visible on server-2
echo ""
echo "Verifying shared file visible on server-2..."
ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=15 \
    ec2-user@"$IP_2" \
    "cat /mnt/efs/driver.log"

echo ""
echo "========================================="
echo "  Solution Applied: Summary"
echo "========================================="
echo ""
echo "Bug 1 Fixed : EFS SG now allows port 2049 from EC2 SG only"
echo "Bug 2 Fixed : fstab entry added on server-2, EFS mounted at /mnt/efs"
echo "Verified    : File written on server-1 is visible on server-2"
echo ""