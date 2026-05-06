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


function test_node_role_get_auth_token() {
    local policy_text
    policy_text=$(aws iam get-role-policy --role-name "${NODE_ROLE}" --policy-name "novapay-eks-node-ecr-policy" --query 'PolicyDocument' --output text 2>/dev/null || true)

    if echo "${policy_text}" | grep -q "ecr:GetAuthorizationToken"; then
        print_status "success" "Lab Passed: Node role inline policy includes ecr:GetAuthorizationToken."
    else
        print_status "failed" "Lab Failed: The inline policy 'novapay-eks-node-ecr-policy' on role '${NODE_ROLE}' is missing 'ecr:GetAuthorizationToken'. Without this action EKS nodes cannot obtain a Docker login token — all ECR image pulls will fail with 'no basic auth credentials' regardless of the repository policy."
        exit 1
    fi
}

function test_payment_processor_batch_get_image() {
    local policy_text
    policy_text=$(aws ecr get-repository-policy --repository-name "novapay/payment-processor" --region "${REGION}" --query 'policyText' --output text 2>/dev/null || true)

    if echo "${policy_text}" | grep -q "ecr:BatchGetImage"; then
        print_status "success" "Lab Passed: novapay/payment-processor repository policy includes ecr:BatchGetImage."
    else
        print_status "failed" "Lab Failed: The repository policy for 'novapay/payment-processor' is missing 'ecr:BatchGetImage' in the NodePull statement. All three pull actions are required — ecr:GetDownloadUrlForLayer, ecr:BatchGetImage, and ecr:BatchCheckLayerAvailability. Without BatchGetImage the image manifest cannot be fetched and pods enter ImagePullBackOff."
        exit 1
    fi
}

function test_payment_processor_all_pull_actions() {
    local policy_text missing_actions
    policy_text=$(aws ecr get-repository-policy --repository-name "novapay/payment-processor" --region "${REGION}" --query 'policyText' --output text 2>/dev/null || true)

    echo "${policy_text}" | grep -q "ecr:GetDownloadUrlForLayer" || missing_actions="${missing_actions} ecr:GetDownloadUrlForLayer"
    echo "${policy_text}" | grep -q "ecr:BatchGetImage"          || missing_actions="${missing_actions} ecr:BatchGetImage"
    echo "${policy_text}" | grep -q "ecr:BatchCheckLayerAvailability" || missing_actions="${missing_actions} ecr:BatchCheckLayerAvailability"

    if [ -n "${missing_actions}" ]; then
        print_status "failed" "Lab Failed: The repository policy for 'novapay/payment-processor' is missing pull actions:${missing_actions}. The NodePull statement must grant all three pull actions to the node role."
        exit 1
    fi
    print_status "success" "Lab Passed: novapay/payment-processor repository policy contains all required pull actions."
}

test_node_role_get_auth_token
test_payment_processor_batch_get_image
test_payment_processor_all_pull_actions
print_status "success" "Preliminary Tests Passed: Node IAM policy and payment-processor repository policy pull permissions verified."
exit 0
