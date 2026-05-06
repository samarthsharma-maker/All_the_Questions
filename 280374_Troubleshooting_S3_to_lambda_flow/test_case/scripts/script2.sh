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

function test_s3_event_type() {    
    local event_types
    event_types=$(aws s3api get-bucket-notification-configuration --bucket "$UPLOAD_BUCKET" --region "$REGION" --query 'LambdaFunctionConfigurations[].Events[]' --output text 2>/dev/null || echo "")
    
    if [[ "$event_types" == *"s3:ObjectCreated"* ]]; then
        print_status "success" "Test 3 Passed: S3 event type includes ObjectCreated"
        return 0
    else
        print_status "failed" "Test 3 Failed: S3 event type missing or incorrect (should include s3:ObjectCreated:*)"
        return 1
    fi
}

function test_s3_prefix_filter() {    
    local has_prefix_filter=false
    
    local configs prefix_count
    configs=$(aws s3api get-bucket-notification-configuration --bucket "$UPLOAD_BUCKET" --region "$REGION" --query 'LambdaFunctionConfigurations' --output json 2>/dev/null || echo "[]")
    prefix_count=$(echo "$configs" | jq '[.[] | select(.Filter.Key.FilterRules[]? | select(.Name == "prefix" and .Value == "uploads/"))] | length' 2>/dev/null || echo "0")
    
    if [ "$prefix_count" -gt 0 ]; then
        print_status "success" "Test 4 Passed: S3 event has prefix filter 'uploads/'"
        return 0
    else
        print_status "failed" "Test 4 Failed: S3 event missing prefix filter 'uploads/'"
        return 1
    fi
}

test_s3_event_type
test_s3_prefix_filter
print_status "success" "Lab Passed: S3 event type and prefix filter verified successfully."
exit 0
