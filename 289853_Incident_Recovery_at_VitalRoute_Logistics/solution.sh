#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
BUCKET_NAME="vitalroute-reports-${ACCOUNT_ID}"
FILE_NAME="report.csv"

echo "Resolving bucket: $BUCKET_NAME"

# Task 1: Recover the deleted file by removing the delete marker

echo ""
echo "Listing versions to find delete marker..."
DELETE_MARKER_VERSION_ID=$(aws s3api list-object-versions \
    --bucket "$BUCKET_NAME" \
    --prefix "$FILE_NAME" \
    --region "$REGION" \
    --query "DeleteMarkers[?Key=='${FILE_NAME}'].VersionId" \
    --output text)

echo "Delete marker version ID: $DELETE_MARKER_VERSION_ID"

aws s3api delete-object \
    --bucket "$BUCKET_NAME" \
    --key "$FILE_NAME" \
    --version-id "$DELETE_MARKER_VERSION_ID" \
    --region "$REGION"

echo "Delete marker removed. Verifying file recovery..."
aws s3 ls "s3://${BUCKET_NAME}/${FILE_NAME}"

# Task 2: Enable public access block

echo ""
echo "Enabling public access block on bucket..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Verifying public access block..."
aws s3api get-public-access-block --bucket "$BUCKET_NAME" --region "$REGION"

# Task 3: Add lifecycle rule for non-current version expiry

echo ""
echo "Adding lifecycle rule..."
cat > /tmp/lifecycle.json << 'EOF'
{
  "Rules": [
    {
      "ID": "expire-old-versions",
      "Status": "Enabled",
      "Filter": {
        "Prefix": ""
      },
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 30
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --lifecycle-configuration file:///tmp/lifecycle.json

echo "Verifying lifecycle rule..."
aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET_NAME" --region "$REGION"

echo ""
echo "========================================="
echo "  Solution Applied: Summary"
echo "========================================="
echo ""
echo "File Recovery"
echo "  Delete marker removed from report.csv"
echo "  File restored to its previous version"
echo ""
echo "Public Access"
echo "  Before : All four public access block settings were OFF"
echo "  After  : All four public access block settings are ON"
echo ""
echo "Lifecycle Rule"
echo "  Rule    : expire-old-versions"
echo "  Target  : Non-current versions of all objects"
echo "  Action  : Expire after 30 days"
echo ""