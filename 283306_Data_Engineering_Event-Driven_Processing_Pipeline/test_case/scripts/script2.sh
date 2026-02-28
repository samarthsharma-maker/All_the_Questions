#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PROCESSED_BUCKET="salary-processed-bucket-${ACCOUNT_ID}"
OUTPUT_KEY="output/deptMonthAggSalary${ACCOUNT_ID}.csv"

function test_all_departments_present() {
    local content missing_depts
    content=$(aws s3 cp "s3://${PROCESSED_BUCKET}/${OUTPUT_KEY}" - --region "$REGION" 2>/dev/null)

    missing_depts=""
    for dept in 101 102 103 104 105; do
        if ! echo "$content" | grep -q "^${dept},"; then
            missing_depts="${missing_depts} ${dept}"
        fi
    done

    if [ -z "$missing_depts" ]; then
        print_status "success" "Test 4 Passed: All departments (101-105) present in output"
    else
        print_status "failed" "Test 4 Failed: Missing departments:${missing_depts}"
        exit 1
    fi
}

function test_only_march_present() {
    local content unexpected_months
    content=$(aws s3 cp "s3://${PROCESSED_BUCKET}/${OUTPUT_KEY}" - --region "$REGION" 2>/dev/null)

    unexpected_months=""
    for month in Jan Feb Apr; do
        if echo "$content" | grep -q ",${month},"; then
            unexpected_months="${unexpected_months} ${month}"
        fi
    done

    if [ -z "$unexpected_months" ]; then
        print_status "success" "Test 5 Passed: Only March data is present in output (no Jan/Feb/Apr)"
    else
        print_status "failed" "Test 5 Failed: Unexpected months found in output:${unexpected_months}"
        exit 1
    fi
}

function test_march_month_present() {
    local content
    content=$(aws s3 cp "s3://${PROCESSED_BUCKET}/${OUTPUT_KEY}" - --region "$REGION" 2>/dev/null)

    if echo "$content" | grep -q ",Mar,"; then
        print_status "success" "Test 6 Passed: March month is present in output"
    else
        print_status "failed" "Test 6 Failed: March month is missing from output"
        exit 1
    fi
}

test_all_departments_present
test_only_march_present
test_march_month_present

print_status "success" "Department and Month Presence Tests Passed."
exit 0