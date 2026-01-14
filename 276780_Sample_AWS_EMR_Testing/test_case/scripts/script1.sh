#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

BUCKET=$(aws s3 ls | awk '{print $3}' | grep "^$prefix" | head -n1)
if [[ -z "$BUCKET" ]]; then
    print_status "failed" "S3 bucket with prefix '$prefix' not found."
    exit 1
fi

aws s3 ls "s3://$BUCKET/scripts/" --no-cli-pager >/dev/null 2>&1 || {
    print_status "failed" "Bucket '$BUCKET' does not contain 'scripts/' folder"
    exit 1
}

aws s3 ls "s3://$BUCKET/scripts/query.sql" --no-cli-pager >/dev/null 2>&1 || {
    print_status "failed" "'query.sql' not found in 'scripts/' folder of bucket '$BUCKET'"
    exit 1
}

print_status "success" "S3 bucket and required files verified."
exit 0