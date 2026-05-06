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


function test_fraud_detection_put_image() {
    local policy_text
    policy_text=$(aws ecr get-repository-policy --repository-name "novapay/fraud-detection" --region "${REGION}" --query 'policyText' --output text 2>/dev/null || true)

    if echo "${policy_text}" | grep -q "ecr:PutImage"; then
        print_status "success" "Lab Passed: novapay/fraud-detection repository policy includes ecr:PutImage."
    else
        print_status "failed" "Lab Failed: The repository policy for 'novapay/fraud-detection' is missing 'ecr:PutImage' for the CI/CD role. Without push actions the CI/CD pipeline cannot push images — docker push will fail with 'authorization failed' at the manifest put stage."
        exit 1
    fi
}

function test_fraud_detection_all_push_actions() {
    local policy_text missing_actions
    policy_text=$(aws ecr get-repository-policy --repository-name "novapay/fraud-detection" --region "${REGION}" --query 'policyText' --output text 2>/dev/null || true)

    echo "${policy_text}" | grep -q "ecr:PutImage"              || missing_actions="${missing_actions} ecr:PutImage"
    echo "${policy_text}" | grep -q "ecr:InitiateLayerUpload"   || missing_actions="${missing_actions} ecr:InitiateLayerUpload"
    echo "${policy_text}" | grep -q "ecr:UploadLayerPart"       || missing_actions="${missing_actions} ecr:UploadLayerPart"
    echo "${policy_text}" | grep -q "ecr:CompleteLayerUpload"   || missing_actions="${missing_actions} ecr:CompleteLayerUpload"

    if [ -n "${missing_actions}" ]; then
        print_status "failed" "Lab Failed: The repository policy for 'novapay/fraud-detection' is missing CI/CD push actions:${missing_actions}. All four push actions must be granted to '${CICD_ROLE_ARN}'."
        exit 1
    fi
    print_status "success" "Lab Passed: novapay/fraud-detection repository policy contains all four required push actions for the CI/CD role."
}


function test_batch_runner_node_role_present() {
    local policy_text
    policy_text=$(aws ecr get-repository-policy --repository-name "novapay/batch-runner" --region "${REGION}" --query 'policyText' --output text 2>/dev/null || true)

    if echo "${policy_text}" | grep -q "${NODE_ROLE_ARN}"; then
        print_status "success" "Lab Passed: novapay/batch-runner repository policy includes the node role ARN."
    else
        print_status "failed" "Lab Failed: The repository policy for 'novapay/batch-runner' does not include the node role ARN '${NODE_ROLE_ARN}'. EKS nodes cannot pull the batch-runner image — pods will enter ImagePullBackOff. Add a statement granting pull actions to the node role."
        exit 1
    fi
}

function test_batch_runner_node_pull_actions() {
    local policy_text missing_actions
    policy_text=$(aws ecr get-repository-policy --repository-name "novapay/batch-runner" --region "${REGION}" --query 'policyText' --output text 2>/dev/null || true)

    echo "${policy_text}" | grep -q "ecr:GetDownloadUrlForLayer"      || missing_actions="${missing_actions} ecr:GetDownloadUrlForLayer"
    echo "${policy_text}" | grep -q "ecr:BatchGetImage"               || missing_actions="${missing_actions} ecr:BatchGetImage"
    echo "${policy_text}" | grep -q "ecr:BatchCheckLayerAvailability" || missing_actions="${missing_actions} ecr:BatchCheckLayerAvailability"

    if [ -n "${missing_actions}" ]; then
        print_status "failed" "Lab Failed: The repository policy for 'novapay/batch-runner' is missing pull actions:${missing_actions}. The node role statement must grant all three pull actions so EKS nodes can pull the batch-runner image."
        exit 1
    fi
    print_status "success" "Lab Passed: novapay/batch-runner repository policy grants all required pull actions."
}

test_fraud_detection_put_image
test_fraud_detection_all_push_actions
test_batch_runner_node_role_present
test_batch_runner_node_pull_actions
print_status "success" "Preliminary Tests Passed: fraud-detection repository policy push permissions and batch-runner node role presence verified."
exit 0