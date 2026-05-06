#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
BUCKET_NAME="vitalroute-reports-${ACCOUNT_ID}"
FILE_NAME="report.csv"

function test_file_is_accessible() {
    local result
    result=$(aws s3 ls "s3://${BUCKET_NAME}/${FILE_NAME}" 2>/dev/null || echo "")
    if [ -z "$result" ]; then
        print_status "failed" "Lab Failed: report.csv is not accessible in the bucket. Navigate to the S3 console, enable Show versions, find the delete marker for report.csv, and delete it using its version ID."
        exit 1
    fi
    print_status "success" "Lab Passed: report.csv is accessible in the bucket."
}

function test_no_delete_marker() {
    local marker_count
    marker_count=$(aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --prefix "$FILE_NAME" \
        --region "$REGION" \
        --query "length(DeleteMarkers[?Key=='${FILE_NAME}'])" \
        --output text 2>/dev/null || echo "0")

    if [ "$marker_count" != "0" ] && [ "$marker_count" != "None" ]; then
        print_status "failed" "Lab Failed: A delete marker still exists for report.csv. Delete the marker (not the file version) using its version ID to fully recover the file."
        exit 1
    fi
    print_status "success" "Lab Passed: No delete marker found. File is cleanly recovered."
}

test_file_is_accessible
test_no_delete_marker

print_status "success" "Lab Passed: report.csv has been successfully recovered from the versioned bucket."
exit 0