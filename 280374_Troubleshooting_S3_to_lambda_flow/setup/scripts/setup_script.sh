#!/bin/bash

set -euo pipefail

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
apt update
apt install -y zip
echo "Setting up S3 Lambda event notification environment in ${REGION}"

echo "Creating S3 bucket..."
UPLOAD_BUCKET="image-uploads-${ACCOUNT_ID}"

aws s3 mb "s3://${UPLOAD_BUCKET}" --region "$REGION" 2>/dev/null || true

aws s3api put-bucket-versioning --bucket "$UPLOAD_BUCKET" --versioning-configuration Status=Enabled --region "$REGION"

echo "Creating processed images bucket..."
PROCESSED_BUCKET="processed-images-${ACCOUNT_ID}"

aws s3 mb "s3://${PROCESSED_BUCKET}" --region "$REGION" 2>/dev/null || true

echo "Creating Dead Letter Queue..."
DLQ_URL=$(aws sqs create-queue --queue-name ImageProcessingDLQ --region "$REGION" --query 'QueueUrl' --output text 2>/dev/null || \
    aws sqs get-queue-url --queue-name ImageProcessingDLQ --region "$REGION" --query 'QueueUrl' --output text)

DLQ_ARN=$(aws sqs get-queue-attributes --queue-url "$DLQ_URL" --attribute-names QueueArn --region "$REGION" --query 'Attributes.QueueArn' --output text)

echo "Creating Lambda IAM role..."
cat > /tmp/lambda-trust-policy.json <<'TRUST'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
TRUST

aws iam create-role --role-name ImageProcessorRole --assume-role-policy-document file:///tmp/lambda-trust-policy.json 2>/dev/null || echo "Role already exists"

sleep 5

aws iam attach-role-policy --role-name ImageProcessorRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

cat > /tmp/lambda-policy.json <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::${UPLOAD_BUCKET}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::${PROCESSED_BUCKET}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage"
      ],
      "Resource": "${DLQ_ARN}"
    }
  ]
}
POLICY

aws iam put-role-policy --role-name ImageProcessorRole --policy-name LambdaS3AccessPolicy --policy-document file:///tmp/lambda-policy.json
echo "Creating Lambda function..."

cat > /tmp/lambda_function.py <<'LAMBDA'
import json
import boto3
import os
from urllib.parse import unquote_plus

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    
    processed_bucket = os.environ.get('PROCESSED_BUCKET')
    
    if not processed_bucket:
        raise Exception("PROCESSED_BUCKET environment variable not set")
    
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])
        
        print(f"Processing file: {key} from bucket: {bucket}")
        
        # Get the object
        response = s3_client.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read()
        
        # Simulate processing - copy to processed bucket
        processed_key = f"processed/{key}"
        s3_client.put_object(
            Bucket=processed_bucket,
            Key=processed_key,
            Body=content,
            Metadata={'original-bucket': bucket, 'original-key': key}
        )
        
        print(f"Successfully processed {key} to {processed_key}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Image processing completed')
    }
LAMBDA

cd /tmp
zip -q lambda_function.zip lambda_function.py

LAMBDA_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/ImageProcessorRole"

sleep 10

aws lambda delete-function --function-name ImageProcessor --region "$REGION" 2>/dev/null || true

sleep 2

LAMBDA_ARN=$(aws lambda create-function --function-name ImageProcessor --runtime python3.11 --role "$LAMBDA_ROLE_ARN" --handler lambda_function.lambda_handler --zip-file fileb:///tmp/lambda_function.zip --timeout 30 --memory-size 256 --region "$REGION" --query 'FunctionArn' --output text)
echo "Lambda function created: $LAMBDA_ARN"
echo "Skipping environment variable configuration (intentional issue)..."

echo "Configuring Dead Letter Queue (with intentional issue)..."
aws lambda update-function-configuration --function-name ImageProcessor --dead-letter-config TargetArn="${DLQ_URL}" --region "$REGION" 2>/dev/null || echo "DLQ configuration skipped"

echo "Skipping Lambda invoke permission (intentional issue)..."

echo "Skipping S3 event notification (intentional issue)..."

cat > /tmp/s3_lambda_env.txt <<ENV
REGION=$REGION
ACCOUNT_ID=$ACCOUNT_ID
UPLOAD_BUCKET=$UPLOAD_BUCKET
PROCESSED_BUCKET=$PROCESSED_BUCKET
LAMBDA_ARN=$LAMBDA_ARN
LAMBDA_NAME=ImageProcessor
DLQ_URL=$DLQ_URL
DLQ_ARN=$DLQ_ARN
ENV

echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "Environment details saved to: /tmp/s3_lambda_env.txt"
echo ""
echo "To view your environment details, run:"
echo "  cat /tmp/s3_lambda_env.txt"
echo ""
echo "Upload bucket: s3://${UPLOAD_BUCKET}"
echo "Processed bucket: s3://${PROCESSED_BUCKET}"
echo ""
echo "========================================"

# Clean up temp files
rm -f /tmp/lambda-trust-policy.json /tmp/lambda-policy.json /tmp/lambda_function.py /tmp/lambda_function.zip

# ==========================================
# SOLUTION SCRIPT: S3 Lambda Event Trigger Fix
# ==========================================

echo "==========================================="
echo "S3 Lambda Event Notification Fix Solution"
echo "==========================================="
echo ""

REGION="${AWS_REGION:-us-west-2}"

# Get account ID and derive resource names
echo "Getting AWS account information..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$ACCOUNT_ID" ]; then
    echo "Error: Could not retrieve AWS account ID"
    exit 1
fi

# Define predictable resource names
UPLOAD_BUCKET="image-uploads-${ACCOUNT_ID}"
PROCESSED_BUCKET="processed-images-${ACCOUNT_ID}"
LAMBDA_NAME="ImageProcessor"
DLQ_NAME="ImageProcessingDLQ"

echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo "Upload Bucket: $UPLOAD_BUCKET"
echo "Processed Bucket: $PROCESSED_BUCKET"
echo "Lambda Function: $LAMBDA_NAME"
echo ""

# Get Lambda ARN
LAMBDA_ARN=$(aws lambda get-function \
    --function-name "$LAMBDA_NAME" \
    --region "$REGION" \
    --query 'Configuration.FunctionArn' \
    --output text 2>/dev/null)

if [ -z "$LAMBDA_ARN" ]; then
    echo "Error: Lambda function '$LAMBDA_NAME' not found"
    exit 1
fi

echo "Lambda ARN: $LAMBDA_ARN"
echo ""

# Get DLQ ARN
DLQ_URL=$(aws sqs get-queue-url \
    --queue-name "$DLQ_NAME" \
    --region "$REGION" \
    --query 'QueueUrl' \
    --output text 2>/dev/null)

DLQ_ARN=$(aws sqs get-queue-attributes \
    --queue-url "$DLQ_URL" \
    --attribute-names QueueArn \
    --region "$REGION" \
    --query 'Attributes.QueueArn' \
    --output text 2>/dev/null)

echo "DLQ ARN: $DLQ_ARN"
echo ""

echo "==========================================="
echo "Applying Fixes..."
echo "==========================================="
echo ""

# ==========================================
# FIX 1: Add Lambda Permission for S3 Invocation
# ==========================================
echo "Fix 1: Adding S3 invoke permission to Lambda..."

set +e
aws lambda add-permission \
    --function-name "$LAMBDA_NAME" \
    --statement-id S3InvokePermission \
    --action lambda:InvokeFunction \
    --principal s3.amazonaws.com \
    --source-arn "arn:aws:s3:::${UPLOAD_BUCKET}" \
    --source-account "$ACCOUNT_ID" \
    --region "$REGION" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "  [SUCCESS] S3 invoke permission added to Lambda"
else
    echo "  [INFO] Permission already exists or could not be added"
fi
set -e

echo ""

# ==========================================
# FIX 2: Configure S3 Event Notification
# ==========================================
echo "Fix 2: Configuring S3 event notification with filters..."

# Create notification configuration with multiple file type filters
cat > /tmp/s3-notification-config.json <<EOF
{
  "LambdaFunctionConfigurations": [
    {
      "Id": "ImageProcessorTrigger-JPG",
      "LambdaFunctionArn": "${LAMBDA_ARN}",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "prefix",
              "Value": "uploads/"
            },
            {
              "Name": "suffix",
              "Value": ".jpg"
            }
          ]
        }
      }
    },
    {
      "Id": "ImageProcessorTrigger-PNG",
      "LambdaFunctionArn": "${LAMBDA_ARN}",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "prefix",
              "Value": "uploads/"
            },
            {
              "Name": "suffix",
              "Value": ".png"
            }
          ]
        }
      }
    },
    {
      "Id": "ImageProcessorTrigger-GIF",
      "LambdaFunctionArn": "${LAMBDA_ARN}",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "prefix",
              "Value": "uploads/"
            },
            {
              "Name": "suffix",
              "Value": ".gif"
            }
          ]
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-notification-configuration \
    --bucket "$UPLOAD_BUCKET" \
    --notification-configuration file:///tmp/s3-notification-config.json \
    --region "$REGION"

if [ $? -eq 0 ]; then
    echo "  [SUCCESS] S3 event notification configured with prefix and suffix filters"
else
    echo "  [ERROR] Failed to configure S3 event notification"
fi

echo ""

# ==========================================
# FIX 3: Set Lambda Environment Variable
# ==========================================
echo "Fix 3: Setting Lambda environment variable PROCESSED_BUCKET..."

aws lambda update-function-configuration \
    --function-name "$LAMBDA_NAME" \
    --environment "Variables={PROCESSED_BUCKET=${PROCESSED_BUCKET}}" \
    --region "$REGION" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "  [SUCCESS] Environment variable PROCESSED_BUCKET set to '$PROCESSED_BUCKET'"
else
    echo "  [ERROR] Failed to set environment variable"
fi

echo ""

# ==========================================
# FIX 4: Fix Dead Letter Queue Configuration
# ==========================================
echo "Fix 4: Configuring Dead Letter Queue with correct ARN format..."

aws lambda update-function-configuration \
    --function-name "$LAMBDA_NAME" \
    --dead-letter-config TargetArn="${DLQ_ARN}" \
    --region "$REGION" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "  [SUCCESS] Dead Letter Queue configured with ARN: $DLQ_ARN"
else
    echo "  [ERROR] Failed to configure Dead Letter Queue"
fi

echo ""

echo "==========================================="
echo "All Fixes Applied!"
echo "==========================================="
echo ""

# ==========================================
# VERIFICATION
# ==========================================
echo "Verifying configuration..."
echo ""

# Wait for Lambda configuration to update
echo "Waiting 5 seconds for configuration to propagate..."
sleep 5

# Verify Lambda permission
echo "Verifying Lambda resource policy..."
POLICY_CHECK=$(aws lambda get-policy \
    --function-name "$LAMBDA_NAME" \
    --region "$REGION" \
    --query 'Policy' \
    --output text 2>/dev/null | jq -r '.Statement[] | select(.Principal.Service == "s3.amazonaws.com") | .Effect' 2>/dev/null || echo "")

if [ "$POLICY_CHECK" == "Allow" ]; then
    echo "  [OK] Lambda has S3 invoke permission"
else
    echo "  [WARNING] Could not verify Lambda permission"
fi

# Verify S3 notification
echo "Verifying S3 event notification..."
NOTIFICATION_CHECK=$(aws s3api get-bucket-notification-configuration \
    --bucket "$UPLOAD_BUCKET" \
    --region "$REGION" \
    --query 'LambdaFunctionConfigurations | length(@)' \
    --output text 2>/dev/null || echo "0")

if [ "$NOTIFICATION_CHECK" -gt 0 ]; then
    echo "  [OK] S3 event notification configured ($NOTIFICATION_CHECK configuration(s))"
else
    echo "  [WARNING] S3 event notification may not be configured"
fi

# Verify environment variable
echo "Verifying Lambda environment variable..."
ENV_CHECK=$(aws lambda get-function-configuration \
    --function-name "$LAMBDA_NAME" \
    --region "$REGION" \
    --query 'Environment.Variables.PROCESSED_BUCKET' \
    --output text 2>/dev/null || echo "")

if [ "$ENV_CHECK" == "$PROCESSED_BUCKET" ]; then
    echo "  [OK] PROCESSED_BUCKET environment variable set correctly"
else
    echo "  [WARNING] Environment variable may not be set correctly"
fi

# Verify DLQ
echo "Verifying Dead Letter Queue configuration..."
DLQ_CHECK=$(aws lambda get-function-configuration \
    --function-name "$LAMBDA_NAME" \
    --region "$REGION" \
    --query 'DeadLetterConfig.TargetArn' \
    --output text 2>/dev/null || echo "")

if [[ "$DLQ_CHECK" == arn:aws:sqs:* ]]; then
    echo "  [OK] Dead Letter Queue configured with ARN format"
else
    echo "  [WARNING] Dead Letter Queue may not be configured correctly"
fi

echo ""
echo "==========================================="
echo "Testing End-to-End Functionality"
echo "==========================================="
echo ""

# Create and upload test file
echo "Creating test image..."
TEST_FILE="/tmp/test-solution-$$.jpg"
echo "Test image content from solution script at $(date)" > "$TEST_FILE"

echo "Uploading test image to s3://$UPLOAD_BUCKET/uploads/test-solution-$$.jpg"
aws s3 cp "$TEST_FILE" "s3://$UPLOAD_BUCKET/uploads/test-solution-$$.jpg" \
    --region "$REGION" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "  [OK] Test file uploaded successfully"
else
    echo "  [ERROR] Failed to upload test file"
fi

echo ""
echo "Waiting 15 seconds for Lambda to process the image..."
sleep 15

# Check for processed file
echo "Checking for processed file..."
PROCESSED_FILE=$(aws s3 ls "s3://$PROCESSED_BUCKET/processed/uploads/test-solution-$$.jpg" \
    --region "$REGION" 2>/dev/null || echo "")

if [ -n "$PROCESSED_FILE" ]; then
    echo "  [SUCCESS] Processed file found in s3://$PROCESSED_BUCKET/processed/uploads/"
    echo ""
    echo "End-to-end test PASSED!"
else
    echo "  [WARNING] Processed file not found yet (may need more time)"
    echo ""
    echo "Check CloudWatch Logs for Lambda execution:"
    echo "  aws logs tail /aws/lambda/$LAMBDA_NAME --since 5m --region $REGION"
fi

# Clean up test file
rm -f "$TEST_FILE" /tmp/s3-notification-config.json

echo ""
echo "==========================================="
echo "Fix Summary"
echo "==========================================="
echo ""
echo "The following fixes have been applied:"
echo "  1. [DONE] Lambda permission added for S3 invocation"
echo "  2. [DONE] S3 event notification configured with filters:"
echo "           - Prefix: uploads/"
echo "           - Suffix: .jpg, .png, .gif"
echo "           - Event: s3:ObjectCreated:*"
echo "  3. [DONE] Lambda environment variable PROCESSED_BUCKET set"
echo "  4. [DONE] Dead Letter Queue configured with ARN format"
echo ""
echo "To test manually:"
echo "  1. Upload an image:"
echo "     aws s3 cp image.jpg s3://$UPLOAD_BUCKET/uploads/image.jpg"
echo ""
echo "  2. Wait a few seconds, then check processed bucket:"
echo "     aws s3 ls s3://$PROCESSED_BUCKET/processed/uploads/"
echo ""
echo "  3. Check CloudWatch Logs:"
echo "     aws logs tail /aws/lambda/$LAMBDA_NAME --since 10m"
echo ""
echo "==========================================="