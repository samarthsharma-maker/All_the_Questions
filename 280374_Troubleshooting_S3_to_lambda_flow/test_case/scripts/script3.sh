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

function test_s3_suffix_filter() {    
    local configs image_suffix_count
    configs=$(aws s3api get-bucket-notification-configuration --bucket "$UPLOAD_BUCKET" --region "$REGION" --query 'LambdaFunctionConfigurations' --output json 2>/dev/null || echo "[]")
    image_suffix_count=$(echo "$configs" | jq '[.[] | select(.Filter.Key.FilterRules[]? | select(.Name == "suffix" and (.Value == ".jpg" or .Value == ".png" or .Value == ".gif")))] | length' 2>/dev/null || echo "0")
    
    if [ "$image_suffix_count" -gt 0 ]; then
        print_status "success" "Test 5 Passed: S3 event has suffix filter for image files (.jpg, .png, or .gif)"
        return 0
    else
        print_status "failed" "Test 5 Failed: S3 event missing suffix filter for images (.jpg, .png, .gif)"
        return 1
    fi
}

function test_lambda_environment_variable() {
    local env_var
    env_var=$(aws lambda get-function-configuration --function-name "$LAMBDA_NAME" --region "$REGION" --query 'Environment.Variables.PROCESSED_BUCKET' --output text 2>/dev/null || echo "")
    
    if [ -z "$env_var" ] || [ "$env_var" == "None" ]; then
        print_status "failed" "Test 6 Failed: Lambda missing PROCESSED_BUCKET environment variable"
        return 1
    fi
    
    if [ "$env_var" == "$PROCESSED_BUCKET" ]; then
        print_status "success" "Test 6 Passed: Lambda has PROCESSED_BUCKET environment variable set correctly"
        return 0
    else
        print_status "failed" "Test 6 Failed: Lambda PROCESSED_BUCKET variable set to '$env_var' (expected: '$PROCESSED_BUCKET')"
        return 1
    fi
}


test_s3_suffix_filter
test_lambda_environment_variable
print_status "success" "Environment Variable and Suffix Filter Tests Passed."
exit 0
