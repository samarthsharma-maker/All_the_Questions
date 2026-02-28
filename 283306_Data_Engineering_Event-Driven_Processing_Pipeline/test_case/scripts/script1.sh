#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PROCESSED_BUCKET="salary-processed-bucket-${ACCOUNT_ID}"
OUTPUT_KEY="output/deptMonthAggSalary${ACCOUNT_ID}.csv"

function test_output_file_exists() {
    local file_check
    file_check=$(aws s3 ls "s3://${PROCESSED_BUCKET}/${OUTPUT_KEY}" --region "$REGION" 2>/dev/null || echo "")

    if [ -n "$file_check" ]; then
        print_status "success" "Test 1 Passed: Output file exists at s3://${PROCESSED_BUCKET}/${OUTPUT_KEY}"
    else
        print_status "failed" "Test 1 Failed: Output file NOT found at s3://${PROCESSED_BUCKET}/${OUTPUT_KEY}"
        exit 1
    fi
}

function test_output_header() {
    local header
    header=$(aws s3 cp "s3://${PROCESSED_BUCKET}/${OUTPUT_KEY}" - --region "$REGION" 2>/dev/null | head -1 | tr -d '\r')

    if [ "$header" == "dept_id,month,total_salary" ]; then
        print_status "success" "Test 2 Passed: Output file has correct header"
    else
        print_status "failed" "Test 2 Failed: Incorrect header. Expected 'dept_id,month,total_salary', got '${header}'"
        exit 1
    fi
}

function test_output_not_empty() {
    local row_count
    row_count=$(aws s3 cp "s3://${PROCESSED_BUCKET}/${OUTPUT_KEY}" - --region "$REGION" 2>/dev/null | tail -n +2 | grep -c '.' || echo "0")

    if [ "$row_count" -gt 0 ]; then
        print_status "success" "Test 3 Passed: Output file has ${row_count} data rows"
    else
        print_status "failed" "Test 3 Failed: Output file has no data rows"
        exit 1
    fi
}

test_output_file_exists
test_output_header
test_output_not_empty

print_status "success" "Preliminary Tests Passed: Output file existence, header, and non-empty data verified."
exit 0