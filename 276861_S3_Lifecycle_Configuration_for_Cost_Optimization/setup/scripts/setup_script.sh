#!/bin/bash

set -euo pipefail


create_s3_bucket() {
    local region="${AWS_REGION:-us-west-2}"
    local account_id=$(aws sts get-caller-identity --query Account --output text)

    if [ -z "$account_id" ]; then
        echo "Failed to retrieve AWS Account ID" >&2
        return 1
    fi

    local bucket_name="mgt-lifecycle-lab-${account_id}"
    echo "Creating S3 bucket: s3://${bucket_name} in region ${region}" >&2

    if aws s3 mb "s3://${bucket_name}" --region "$region"; then
        echo "$bucket_name"
    else
        echo "Failed to create bucket ${bucket_name}" >&2
        return 1
    fi
}

create_s3_bucket