#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
BUCKET_NAME="vitalroute-reports-${ACCOUNT_ID}"
FILE_NAME="report.csv"
LAB_DIR="/home/user/vitalroute-s3-lab"

mkdir -p "$LAB_DIR"

echo "Installing jq..."
apt update
apt-get install -y jq > /dev/null 2>&1 || yum install -y jq > /dev/null 2>&1

# Step 1: Create the S3 bucket
echo "Creating S3 bucket: $BUCKET_NAME..."
aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"

# Step 2: Enable versioning
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

# Step 3: Disable public access block (intentional misconfiguration for the lab)
echo "Disabling public access block..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

# Step 4: Create and upload the report file
echo "Uploading $FILE_NAME..."
cat > "$LAB_DIR/$FILE_NAME" << 'CSVEOF'
delivery_id,driver_id,city,status,timestamp
D-1001,DRV-9921,Bengaluru,delivered,2024-04-01T10:22:00
D-1002,DRV-4432,Mumbai,in_transit,2024-04-01T10:45:00
D-1003,DRV-7891,Delhi,delivered,2024-04-01T11:03:00
D-1004,DRV-2210,Hyderabad,failed,2024-04-01T11:20:00
D-1005,DRV-5567,Chennai,delivered,2024-04-01T11:45:00
CSVEOF

aws s3 cp "$LAB_DIR/$FILE_NAME" "s3://${BUCKET_NAME}/${FILE_NAME}"

# Step 5: Delete the file (creates a delete marker)
echo "Deleting $FILE_NAME (creating delete marker)..."
aws s3 rm "s3://${BUCKET_NAME}/${FILE_NAME}"

chown -R user:user "$LAB_DIR"

echo ""
echo "========================================="
echo "  VitalRoute S3 Lab Environment Ready"
echo "========================================="
echo ""
echo "Bucket name : $BUCKET_NAME"
echo ""
echo "Situation:"
echo "  The daily delivery report (report.csv) has been accidentally deleted."
echo "  Public access on the bucket is also misconfigured and must be locked down."
echo "  A data retention policy needs to be applied to manage old file versions."
echo ""
echo "Your tasks:"
echo "  1. Recover report.csv from the versioned bucket"
echo "  2. Disable public access on the bucket"
echo "  3. Add a lifecycle rule to expire non-current versions after 30 days"
echo ""
echo "Bucket name to use in all commands:"
echo "  $BUCKET_NAME"
echo ""