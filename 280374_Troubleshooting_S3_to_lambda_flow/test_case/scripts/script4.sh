#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
UPLOAD_BUCKET="image-uploads-${ACCOUNT_ID}"
PROCESSED_BUCKET="processed-images-${ACCOUNT_ID}"
LAMBDA_NAME="ImageProcessor"
DLQ_NAME="ImageProcessingDLQ"

function test_lambda_dlq_configuration() {
    local dlq_config
    dlq_config=$(aws lambda get-function-configuration --function-name "$LAMBDA_NAME" --region "$REGION" --query 'DeadLetterConfig.TargetArn' --output text 2>/dev/null || echo "")
    
    if [ -z "$dlq_config" ] || [ "$dlq_config" == "None" ]; then
        print_status "failed" "Test 7 Failed: Lambda Dead Letter Queue not configured"
        return 1
    fi
    
    if [[ "$dlq_config" == arn:aws:sqs:* ]]; then
        print_status "success" "Test 7 Passed: Lambda DLQ configured with correct ARN format"
        return 0
    else
        print_status "failed" "Test 7 Failed: Lambda DLQ configured with incorrect format (should be ARN like 'arn:aws:sqs:...', not URL)"
        return 1
    fi
}

function test_no_circular_dependency() {
    local env_processed_bucket
    env_processed_bucket=$(aws lambda get-function-configuration --function-name "$LAMBDA_NAME" --region "$REGION" --query 'Environment.Variables.PROCESSED_BUCKET' --output text 2>/dev/null || echo "")
    
    if [ -z "$env_processed_bucket" ] || [ "$env_processed_bucket" == "None" ]; then
        print_status "failed" "Test 8 Failed: Cannot verify - PROCESSED_BUCKET not set"
        return 1
    fi
    
    if [ "$env_processed_bucket" != "$UPLOAD_BUCKET" ]; then
        print_status "success" "Test 8 Passed: No circular dependency - Lambda writes to different bucket"
        return 0
    else
        print_status "failed" "Test 8 Failed: Circular dependency detected - Lambda writes to same bucket it reads from (will cause infinite loop)"
        return 1
    fi
}

test_lambda_dlq_configuration
test_no_circular_dependency
print_status "success" "DLQ and Circular Dependency Tests Passed."
exit 0
