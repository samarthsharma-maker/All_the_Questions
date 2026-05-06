#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

FUNCTION_NAME="vitalroute-delivery-fn"
REGION="us-west-2"

function test_app_env_is_prod() {
    local env_val
    env_val=$(aws lambda get-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --region "$REGION" \
        --query "Environment.Variables.APP_ENV" \
        --output text 2>/dev/null || echo "")

    if [ -z "$env_val" ] || [ "$env_val" = "None" ]; then
        print_status "failed" "Lab Failed: APP_ENV environment variable is not set on '$FUNCTION_NAME'. Add it using aws lambda update-function-configuration --environment Variables={APP_ENV=prod}."
        exit 1
    fi

    if [ "$env_val" != "prod" ]; then
        print_status "failed" "Lab Failed: APP_ENV is currently set to '$env_val'. It must be set to 'prod' to prevent PII exposure. Run: aws lambda update-function-configuration --function-name $FUNCTION_NAME --environment Variables={APP_ENV=prod} --region $REGION"
        exit 1
    fi

    print_status "success" "Lab Passed: APP_ENV is correctly set to 'prod'."
}

test_app_env_is_prod

print_status "success" "Lab Passed: Lambda environment variable APP_ENV is set to prod."
exit 0