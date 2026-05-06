#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

FUNCTION_NAME="vitalroute-delivery-fn"
REGION="us-west-2"
INVOKE_OUTPUT="/tmp/vitalroute_invoke_output.json"

function test_invocation_succeeds() {
    local http_status
    http_status=$(aws lambda invoke \
        --function-name "$FUNCTION_NAME" \
        --region "$REGION" \
        --payload '{}' \
        --cli-binary-format raw-in-base64-out \
        --query "StatusCode" \
        --output text \
        "$INVOKE_OUTPUT" 2>/dev/null || echo "0")

    if [ "$http_status" != "200" ]; then
        print_status "failed" "Lab Failed: Lambda invocation returned HTTP $http_status instead of 200. Check your function configuration."
        exit 1
    fi
    print_status "success" "Lab Passed: Lambda invocation returned HTTP 200."
}

function test_response_env_is_prod() {
    local body env_val
    body=$(cat "$INVOKE_OUTPUT" 2>/dev/null || echo "")
    env_val=$(echo "$body" | jq -r '.body | fromjson | .env' 2>/dev/null || echo "")

    if [ "$env_val" != "prod" ]; then
        print_status "failed" "Lab Failed: Lambda response shows env='$env_val'. Expected 'prod'. Run: aws lambda update-function-configuration --function-name $FUNCTION_NAME --environment Variables={APP_ENV=prod} --region $REGION"
        exit 1
    fi
    print_status "success" "Lab Passed: Lambda response confirms env is 'prod'."
}

function test_response_has_no_raw_pii() {
    local body
    body=$(cat "$INVOKE_OUTPUT" 2>/dev/null || echo "")

    if echo "$body" | grep -q "Ravi Shankar"; then
        print_status "failed" "Lab Failed: Lambda response contains raw driver name. The function is still running in dev mode. Set APP_ENV=prod."
        exit 1
    fi

    if echo "$body" | grep -q "9876543210"; then
        print_status "failed" "Lab Failed: Lambda response contains raw phone number. The function is still running in dev mode. Set APP_ENV=prod."
        exit 1
    fi

    if echo "$body" | grep -q "HDFC-00291837"; then
        print_status "failed" "Lab Failed: Lambda response contains raw bank account. The function is still running in dev mode. Set APP_ENV=prod."
        exit 1
    fi

    print_status "success" "Lab Passed: Response contains no raw PII fields."
}

function test_response_has_masked_fields() {
    local body name_val phone_val
    body=$(cat "$INVOKE_OUTPUT" 2>/dev/null || echo "")

    name_val=$(echo "$body" | jq -r '.body | fromjson | .data.name' 2>/dev/null || echo "")
    phone_val=$(echo "$body" | jq -r '.body | fromjson | .data.phone' 2>/dev/null || echo "")

    if [ "$name_val" != "R*** S******" ]; then
        print_status "failed" "Lab Failed: Masked name field is '$name_val', expected 'R*** S******'. Ensure APP_ENV=prod and the correct code is deployed."
        exit 1
    fi

    if [ "$phone_val" != "98*****210" ]; then
        print_status "failed" "Lab Failed: Masked phone field is '$phone_val', expected '98*****210'. Ensure APP_ENV=prod and the correct code is deployed."
        exit 1
    fi

    print_status "success" "Lab Passed: Response contains correctly masked name and phone fields."
}

test_invocation_succeeds
test_response_env_is_prod
test_response_has_no_raw_pii
test_response_has_masked_fields

print_status "success" "Lab Passed: Lambda is running in prod mode. Driver PII is correctly masked in all response fields."
exit 0