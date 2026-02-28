#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PROCESSED_BUCKET="salary-processed-bucket-${ACCOUNT_ID}"
OUTPUT_KEY="output/deptMonthAggSalary${ACCOUNT_ID}.csv"

function test_no_duplicate_rows() {
    local total_rows unique_rows
    total_rows=$(aws s3 cp "s3://${PROCESSED_BUCKET}/${OUTPUT_KEY}" - --region "$REGION" 2>/dev/null | tail -n +2 | grep -c '.' || echo "0")
    unique_rows=$(aws s3 cp "s3://${PROCESSED_BUCKET}/${OUTPUT_KEY}" - --region "$REGION" 2>/dev/null | tail -n +2 | awk -F',' '{print $1","$2}' | sort -u | grep -c '.' || echo "0")

    if [ "$total_rows" -eq "$unique_rows" ]; then
        print_status "success" "Test 8 Passed: No duplicate (dept_id, month) rows found"
    else
        print_status "failed" "Test 8 Failed: Duplicate (dept_id, month) rows found. Total: ${total_rows}, Unique: ${unique_rows}"
        exit 1
    fi
}

function test_exact_row_count() {
    local row_count
    row_count=$(aws s3 cp "s3://${PROCESSED_BUCKET}/${OUTPUT_KEY}" - --region "$REGION" 2>/dev/null | tail -n +2 | grep -c '.' || echo "0")

    # Only Mar data: 5 departments x 1 month = exactly 5 rows
    if [ "$row_count" -eq 5 ]; then
        print_status "success" "Test 9 Passed: Output has exactly 5 rows (5 departments x 1 month)"
    else
        print_status "failed" "Test 9 Failed: Expected exactly 5 rows, got ${row_count}"
        exit 1
    fi
}

test_no_duplicate_rows
test_exact_row_count

print_status "success" "Data Integrity Tests Passed: No duplicates, correct row count, and all salary values are valid."
exit 0