#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
BUCKET_NAME="vitalroute-reports-${ACCOUNT_ID}"

function test_public_access_blocked() {
    local config
    config=$(aws s3api get-public-access-block \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --output json 2>/dev/null || echo "")

    if [ -z "$config" ]; then
        print_status "failed" "Lab Failed: Could not retrieve public access block configuration for bucket '$BUCKET_NAME'. Ensure the bucket exists and you are using the correct bucket name."
        exit 1
    fi

    local block_acls ignore_acls block_policy restrict_buckets
    block_acls=$(echo "$config" | jq -r '.PublicAccessBlockConfiguration.BlockPublicAcls')
    ignore_acls=$(echo "$config" | jq -r '.PublicAccessBlockConfiguration.IgnorePublicAcls')
    block_policy=$(echo "$config" | jq -r '.PublicAccessBlockConfiguration.BlockPublicPolicy')
    restrict_buckets=$(echo "$config" | jq -r '.PublicAccessBlockConfiguration.RestrictPublicBuckets')

    if [ "$block_acls" != "true" ]; then
        print_status "failed" "Lab Failed: BlockPublicAcls is not enabled. Run aws s3api put-public-access-block with all four settings set to true."
        exit 1
    fi

    if [ "$ignore_acls" != "true" ]; then
        print_status "failed" "Lab Failed: IgnorePublicAcls is not enabled. Run aws s3api put-public-access-block with all four settings set to true."
        exit 1
    fi

    if [ "$block_policy" != "true" ]; then
        print_status "failed" "Lab Failed: BlockPublicPolicy is not enabled. Run aws s3api put-public-access-block with all four settings set to true."
        exit 1
    fi

    if [ "$restrict_buckets" != "true" ]; then
        print_status "failed" "Lab Failed: RestrictPublicBuckets is not enabled. Run aws s3api put-public-access-block with all four settings set to true."
        exit 1
    fi

    print_status "success" "Lab Passed: All four public access block settings are enabled on the bucket."
}

test_public_access_blocked

print_status "success" "Lab Passed: Bucket public access is fully blocked. No objects can be made public."
exit 0