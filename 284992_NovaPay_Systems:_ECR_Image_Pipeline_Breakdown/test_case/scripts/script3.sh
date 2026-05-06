#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

REGION="us-west-2"
NODE_ROLE="novapay-eks-node-role"
CICD_ROLE="novapay-cicd-role"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
NODE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${NODE_ROLE}"
CICD_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${CICD_ROLE}"

function test_lifecycle_tag_status() {
    local policy_text
    policy_text=$(aws ecr get-lifecycle-policy --repository-name "novapay/fraud-detection" --region "${REGION}" --query 'lifecyclePolicyText' --output text 2>/dev/null || true)

    if echo "${policy_text}" | grep -q '"tagStatus"' && echo "${policy_text}" | grep -q '"untagged"'; then
        print_status "success" "Lab Passed: fraud-detection lifecycle policy tagStatus is set to 'untagged'."
    else
        print_status "failed" "Lab Failed: The lifecycle policy for 'novapay/fraud-detection' does not have tagStatus set to 'untagged'. Using 'any' or 'tagged' will cause the policy to delete actively used production image tags, causing cascading ImagePullBackOff on node restarts. Set tagStatus to 'untagged'."
        exit 1
    fi
}

function test_lifecycle_count_type() {
    local policy_text
    policy_text=$(aws ecr get-lifecycle-policy --repository-name "novapay/fraud-detection" --region "${REGION}" --query 'lifecyclePolicyText' --output text 2>/dev/null || true)

    if echo "${policy_text}" | grep -q '"sinceImagePushed"'; then
        print_status "success" "Lab Passed: fraud-detection lifecycle policy countType is set to 'sinceImagePushed'."
    else
        print_status "failed" "Lab Failed: The lifecycle policy for 'novapay/fraud-detection' does not use countType 'sinceImagePushed'. Using 'imageCountMoreThan' with countNumber 1 would delete all but the single newest image — wiping every production tag in the repository. Set countType to 'sinceImagePushed'."
        exit 1
    fi
}


function test_lifecycle_count_number() {
    local policy_text
    policy_text=$(aws ecr get-lifecycle-policy --repository-name "novapay/fraud-detection" --region "${REGION}" --query 'lifecyclePolicyText' --output text 2>/dev/null || true)

    if echo "${policy_text}" | grep -q '"countNumber"' && echo "${policy_text}" | grep -q '30'; then
        print_status "success" "Lab Passed: fraud-detection lifecycle policy countNumber is set to 30."
    else
        print_status "failed" "Lab Failed: The lifecycle policy for 'novapay/fraud-detection' does not have countNumber set to 30. The policy should expire untagged images older than 30 days. Set countNumber to 30 and countUnit to 'days'."
        exit 1
    fi
}

function test_lifecycle_count_unit() {
    local policy_text
    policy_text=$(aws ecr get-lifecycle-policy --repository-name "novapay/fraud-detection" --region "${REGION}" --query 'lifecyclePolicyText' --output text 2>/dev/null || true)

    if echo "${policy_text}" | grep -q '"days"'; then
        print_status "success" "Lab Passed: fraud-detection lifecycle policy countUnit is set to 'days'."
    else
        print_status "failed" "Lab Failed: The lifecycle policy for 'novapay/fraud-detection' is missing countUnit 'days'. countUnit is required when countType is 'sinceImagePushed' — without it the rule is invalid. Set countUnit to 'days'."
        exit 1
    fi
}
test_lifecycle_tag_status
test_lifecycle_count_type
test_lifecycle_count_number
test_lifecycle_count_unit

print_status "success" "All Lab Tests Passed: node IAM policy, all ECR repository policies, and the fraud-detection lifecycle policy are correctly configured."
exit 0