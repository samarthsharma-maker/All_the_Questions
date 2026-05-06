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

function test_end_to_end_trigger() {
    local timestamp=$(date +%s)
    local test_file="/tmp/test-image-${timestamp}.jpg"
    local s3_key="uploads/test-image-${timestamp}.jpg"
    local processed_key="processed/uploads/test-image-${timestamp}.jpg"
    
    aws s3 cp "$test_file" "s3://$UPLOAD_BUCKET/$s3_key" --region "$REGION" >/dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        print_status "failed" "Test 9 Failed: Could not upload test file to S3"
        rm -f "$test_file"
        return 1
    fi
    
    sleep 5
    local processed_exists
    processed_exists=$(aws s3 ls "s3://$PROCESSED_BUCKET/$processed_key" --region "$REGION" 2>/dev/null || echo "")    
    rm -f "$test_file"
    
    if [ -n "$processed_exists" ]; then
        print_status "success" "Test 9 Passed: Lambda successfully triggered and processed image"
        return 0
    else
        echo "   Checking CloudWatch Logs for Lambda errors..." >&2
        local log_group="/aws/lambda/$LAMBDA_NAME"
        local recent_errors=$(aws logs filter-log-events --log-group-name "$log_group" --start-time $((timestamp * 1000)) --filter-pattern "ERROR" --region "$REGION" --query 'events[0].message' --output text 2>/dev/null || echo "")
        
        if [ -n "$recent_errors" ]; then
            echo "   Lambda error found: $recent_errors" >&2
        fi
        
        print_status "failed" "Test 9 Failed: Processed file not found in s3://$PROCESSED_BUCKET/$processed_key"
        return 1
    fi
}

test_end_to_end_trigger
print_status "success" "End-to-End Trigger Test Completed."
exit 0
