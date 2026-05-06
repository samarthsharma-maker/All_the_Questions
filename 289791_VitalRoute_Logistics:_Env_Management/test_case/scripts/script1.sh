#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

ROLE_NAME="vitalroute-lambda-role"
MANAGED_POLICY_ARN="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

function test_role_exists() {
    local result
    result=$(aws iam get-role --role-name "$ROLE_NAME" --query "Role.RoleName" --output text 2>/dev/null || echo "")
    if [ "$result" != "$ROLE_NAME" ]; then
        print_status "failed" "Lab Failed: IAM role '$ROLE_NAME' does not exist. Create it with a Lambda trust policy."
        exit 1
    fi
    print_status "success" "Lab Passed: IAM role '$ROLE_NAME' exists."
}

function test_trust_policy() {
    local trust
    trust=$(aws iam get-role --role-name "$ROLE_NAME" --query "Role.AssumeRolePolicyDocument" --output json 2>/dev/null || echo "")
    if ! echo "$trust" | grep -q "lambda.amazonaws.com"; then
        print_status "failed" "Lab Failed: IAM role '$ROLE_NAME' does not have a Lambda trust policy. The principal must be lambda.amazonaws.com."
        exit 1
    fi
    print_status "success" "Lab Passed: IAM role has the correct Lambda trust policy."
}

function test_managed_policy_attached() {
    local policies
    policies=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query "AttachedPolicies[*].PolicyArn" --output text 2>/dev/null || echo "")
    if ! echo "$policies" | grep -q "$MANAGED_POLICY_ARN"; then
        print_status "failed" "Lab Failed: AWSLambdaBasicExecutionRole is not attached to '$ROLE_NAME'. Run: aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $MANAGED_POLICY_ARN"
        exit 1
    fi
    print_status "success" "Lab Passed: AWSLambdaBasicExecutionRole is attached to the role."
}

test_role_exists
test_trust_policy
test_managed_policy_attached

print_status "success" "Lab Passed: IAM role is correctly configured with Lambda trust policy and AWSLambdaBasicExecutionRole."
exit 0