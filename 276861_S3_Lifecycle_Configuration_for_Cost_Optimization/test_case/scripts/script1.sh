#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mgt-lifecycle-lab-${ACCOUNT_ID}"

if ! aws s3 ls "s3://${BUCKET_NAME}/logs/active.txt" > /dev/null; then
    print_status "failed" "Active log file not found in 'logs/' folder of bucket '${BUCKET_NAME}'"
    exit 1
fi

if ! aws s3 ls "s3://${BUCKET_NAME}/archives/old.txt" > /dev/null; then
    print_status "failed" "Old log file not found in 'archives/' folder of bucket '${BUCKET_NAME}'"
    exit 1
fi  

if ! aws s3 ls "s3://${BUCKET_NAME}/temp_project.txt" > /dev/null; then
    print_status "failed" "Temporary project file not found in bucket '${BUCKET_NAME}'"
    exit 1
fi

print_status "success" "S3 bucket and required files verified."