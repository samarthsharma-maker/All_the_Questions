#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

FUNCTION_NAME="vitalroute-delivery-fn"
ROLE_NAME="vitalroute-lambda-role"
REGION="us-west-2"

function test_lambda_exists() {
    local result
    result=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" --query "Configuration.FunctionName" --output text 2>/dev/null || echo "")
    if [ "$result" != "$FUNCTION_NAME" ]; then
        print_status "failed" "Lab Failed: Lambda function '$FUNCTION_NAME' does not exist. Create it using aws lambda create-function."
        exit 1
    fi
    print_status "success" "Lab Passed: Lambda function '$FUNCTION_NAME' exists."
}

function test_lambda_uses_correct_role() {
    local role_arn function_role
    role_arn=$(aws iam get-role --role-name "$ROLE_NAME" --query "Role.Arn" --output text 2>/dev/null || echo "")
    function_role=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" --query "Configuration.Role" --output text 2>/dev/null || echo "")
    if [ "$function_role" != "$role_arn" ]; then
        print_status "failed" "Lab Failed: Lambda function is not using role '$ROLE_NAME'. Update the function to reference the correct role ARN."
        exit 1
    fi
    print_status "success" "Lab Passed: Lambda function is using the correct IAM role."
}

function test_lambda_runtime() {
    local runtime
    runtime=$(aws lambda get-function-configuration --function-name "$FUNCTION_NAME" --region "$REGION" --query "Runtime" --output text 2>/dev/null || echo "")
    if [ "$runtime" != "python3.11" ]; then
        print_status "failed" "Lab Failed: Lambda runtime is '$runtime'. Expected 'python3.11'."
        exit 1
    fi
    print_status "success" "Lab Passed: Lambda runtime is correctly set to python3.11."
}

function test_lambda_code_deployed() {
    local code_size
    code_size=$(aws lambda get-function-configuration --function-name "$FUNCTION_NAME" --region "$REGION" --query "CodeSize" --output text 2>/dev/null || echo "0")
    if [ "$code_size" -lt 500 ]; then
        print_status "failed" "Lab Failed: Lambda code size is $code_size bytes which is too small. Run the zip and update-function-code commands to deploy the application code."
        exit 1
    fi
    print_status "success" "Lab Passed: Application code is deployed to the Lambda function (size: ${code_size} bytes)."
}

test_lambda_exists
test_lambda_uses_correct_role
test_lambda_runtime
test_lambda_code_deployed

print_status "success" "Lab Passed: Lambda function exists, uses the correct role and runtime, and has code deployed."
exit 0