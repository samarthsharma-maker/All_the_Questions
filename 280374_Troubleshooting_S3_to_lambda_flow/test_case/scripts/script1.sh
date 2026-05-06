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


function test_lambda_s3_permission() {    
    local policy_check
    policy_check=$(aws lambda get-policy --function-name "$LAMBDA_NAME" --region "$REGION" --query 'Policy' --output text 2>/dev/null || echo "")
    
    if [ -z "$policy_check" ]; then
        print_status "failed" "Test 1 Failed: Lambda function '$LAMBDA_NAME' has no resource policy"
        return 1
    fi

    local s3_permission
    s3_permission=$(echo "$policy_check" | jq -r '.Statement[] | select(.Principal.Service == "s3.amazonaws.com" and (.Action == "lambda:InvokeFunction" or (.Action | type == "array" and .Action[] == "lambda:InvokeFunction"))) | .Effect' 2>/dev/null || echo "")
    
    if [ "$s3_permission" == "Allow" ]; then
        print_status "success" "Test 1 Passed: Lambda has S3 invoke permission"
        return 0
    else
        print_status "failed" "Test 1 Failed: Lambda resource policy missing S3 invoke permission (Principal: s3.amazonaws.com, Action: lambda:InvokeFunction)"
        return 1
    fi
}

function test_s3_event_notification() {
    
    local notification_config config_count lambda_configured
    notification_config=$(aws s3api get-bucket-notification-configuration --bucket "$UPLOAD_BUCKET" --region "$REGION" --query 'LambdaFunctionConfigurations' --output json 2>/dev/null || echo "[]")
    
    config_count=$(echo "$notification_config" | jq '. | length' 2>/dev/null || echo "0")
    
    if [ "$config_count" -eq 0 ]; then
        print_status "failed" "Test 2 Failed: S3 bucket '$UPLOAD_BUCKET' has no Lambda event notification configured"
        return 1
    fi

    lambda_configured=$(echo "$notification_config" | jq -r '.[] | select(.LambdaFunctionArn | contains("ImageProcessor")) | .LambdaFunctionArn' 2>/dev/null || echo "")
    
    if [ -n "$lambda_configured" ]; then
        print_status "success" "Test 2 Passed: S3 event notification configured for Lambda function"
        return 0
    else
        print_status "failed" "Test 2 Failed: S3 event notification not pointing to ImageProcessor Lambda"
        return 1
    fi
}

test_lambda_s3_permission
test_s3_event_notification
print_status "success" "Preliminary Tests Passed: Lambda S3 permission and event notification verified."
exit 0
