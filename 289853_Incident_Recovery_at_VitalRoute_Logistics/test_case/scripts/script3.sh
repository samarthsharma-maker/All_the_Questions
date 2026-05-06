#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
BUCKET_NAME="vitalroute-reports-${ACCOUNT_ID}"

function test_lifecycle_rule_exists() {
    local config
    config=$(aws s3api get-bucket-lifecycle-configuration \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --output json 2>/dev/null || echo "")

    if [ -z "$config" ]; then
        print_status "failed" "Lab Failed: No lifecycle configuration found on bucket '$BUCKET_NAME'. Add a lifecycle rule that expires non-current versions after 30 days."
        exit 1
    fi
    print_status "success" "Lab Passed: Lifecycle configuration exists on the bucket."
}

function test_lifecycle_rule_targets_noncurrent_versions() {
    local config days
    config=$(aws s3api get-bucket-lifecycle-configuration \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --output json 2>/dev/null || echo "")

    days=$(echo "$config" | jq -r '.Rules[].NoncurrentVersionExpiration.NoncurrentDays' 2>/dev/null | grep -v "null" | head -1 || echo "")

    if [ -z "$days" ]; then
        print_status "failed" "Lab Failed: No NoncurrentVersionExpiration found in the lifecycle rule. The rule must target non-current versions, not current objects."
        exit 1
    fi

    if [ "$days" != "30" ]; then
        print_status "failed" "Lab Failed: NoncurrentVersionExpiration is set to $days days. Expected 30 days."
        exit 1
    fi

    print_status "success" "Lab Passed: Lifecycle rule correctly expires non-current versions after 30 days."
}

function test_lifecycle_rule_is_enabled() {
    local config status
    config=$(aws s3api get-bucket-lifecycle-configuration \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --output json 2>/dev/null || echo "")

    status=$(echo "$config" | jq -r '.Rules[].Status' 2>/dev/null | head -1 || echo "")

    if [ "$status" != "Enabled" ]; then
        print_status "failed" "Lab Failed: Lifecycle rule status is '$status'. Set the rule Status to 'Enabled'."
        exit 1
    fi

    print_status "success" "Lab Passed: Lifecycle rule is in Enabled status."
}

test_lifecycle_rule_exists
test_lifecycle_rule_targets_noncurrent_versions
test_lifecycle_rule_is_enabled

print_status "success" "Lab Passed: Lifecycle rule is correctly configured to expire non-current versions after 30 days."
exit 0