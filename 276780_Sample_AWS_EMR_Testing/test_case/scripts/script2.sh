#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

BUCKET=$(aws s3 ls | awk '{print $3}' | grep "^$prefix" | head -n1)

if ! aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
    print_status "failed" "S3 bucket not found: $BUCKET"
    exit 1
fi

APP_ID=$(aws emr-serverless list-applications --region us-west-2 --no-cli-pager --query "applications[?type=='Hive'] | sort_by(@,&createdAt)[-1].id" --output text)
if [[ -z "$APP_ID" ]]; then
    print_status "failed" "EMR Serverless application ID not set"
    exit 1
fi

STATE=$(aws emr-serverless get-application --application-id "$APP_ID" --query 'application.state' --output text)
if [[ "$STATE" != "ACTIVE" && "$STATE" != "STARTED" ]]; then
    print_status "failed" "EMR Serverless application not ACTIVE, current state: $STATE"
    exit 1
fi

print_status "success" "S3 bucket and EMR Serverless application verified."
exit 0