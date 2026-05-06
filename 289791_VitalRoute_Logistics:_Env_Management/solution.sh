#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

LAB_DIR="/home/user/vitalroute-lab"
REGION="us-west-2"
ROLE_NAME="vitalroute-lambda-role"
FUNCTION_NAME="vitalroute-delivery-fn"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

echo "Resolving AWS account ID: $ACCOUNT_ID"

# Step 1: Create IAM role with Lambda trust policy

cat > /tmp/vitalroute-trust-policy.json << 'EOF'
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
EOF

aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file:///tmp/vitalroute-trust-policy.json

echo "Created IAM role: $ROLE_NAME"

aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

echo "Attached AWSLambdaBasicExecutionRole"

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Step 2: Zip the application code

cd "$LAB_DIR"
zip -j function.zip lambda_function.py
echo "Packaged lambda_function.py into function.zip"

# Step 3: Create Lambda with APP_ENV=dev to demonstrate the problem state

echo "Waiting 10 seconds for IAM role propagation..."
sleep 10

aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime python3.11 \
    --role "$ROLE_ARN" \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://function.zip \
    --environment "Variables={APP_ENV=dev}" \
    --timeout 30 \
    --region "$REGION"

echo "Created Lambda function: $FUNCTION_NAME with APP_ENV=dev"

aws lambda wait function-active \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION"

# Step 4: Invoke to show problem state (raw PII)

echo ""
echo "Invoking with APP_ENV=dev (problem state - raw PII):"
aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --payload '{}' \
    --cli-binary-format raw-in-base64-out \
    /tmp/vitalroute_dev_response.json
cat /tmp/vitalroute_dev_response.json

# Step 5: Fix APP_ENV to prod

aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --environment "Variables={APP_ENV=prod}" \
    --region "$REGION"

echo ""
echo "Updated APP_ENV to prod"

aws lambda wait function-updated \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION"

# Step 6: Invoke again to show fixed state (masked data)

echo ""
echo "Invoking with APP_ENV=prod (fixed state - masked data):"
aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --payload '{}' \
    --cli-binary-format raw-in-base64-out \
    /tmp/vitalroute_prod_response.json
cat /tmp/vitalroute_prod_response.json

echo ""
echo "========================================="
echo "  Solution Applied: Summary"
echo "========================================="
echo ""
echo "IAM Role"
echo "  vitalroute-lambda-role created with Lambda trust policy"
echo "  AWSLambdaBasicExecutionRole attached"
echo ""
echo "Lambda Function"
echo "  vitalroute-delivery-fn created with python3.11 runtime"
echo "  Code deployed from lambda_function.py"
echo ""
echo "Environment Variable Fix"
echo "  Before : APP_ENV=dev (raw PII exposed to consumers)"
echo "  After  : APP_ENV=prod (all PII fields masked in response)"
echo ""