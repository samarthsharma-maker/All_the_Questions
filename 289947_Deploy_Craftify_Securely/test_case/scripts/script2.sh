#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

mkdir -p /root/.aws
cp /home/user/.aws/credentials /root/.aws/credentials 2>/dev/null || true
cp /home/user/.aws/config /root/.aws/config 2>/dev/null || true

function load_config() {
    local config="/home/user/craftify-eks-lab/lab-config.txt"
    if [ ! -f "$config" ]; then
        print_status "failed" "Lab Failed: Lab config not found. Run setup.sh first."
        exit 1
    fi
    source "$config"
}

function test_ecr_image_pushed() {
    load_config

    local image_tag
    image_tag=$(aws ecr describe-images \
        --repository-name "$ECR_REPO_NAME" \
        --region "$REGION" \
        --query "imageDetails[?contains(imageTags,'hardened')].imageTags[0]" \
        --output text 2>/dev/null || echo "")

    if [ -z "$image_tag" ] || [ "$image_tag" == "None" ]; then
        print_status "failed" "Lab Failed: No image tagged 'hardened' found in ECR repository '$ECR_REPO_NAME'. Build and push the hardened image."
        exit 1
    fi
    print_status "success" "Lab Passed: Hardened image found in ECR repository."
}

function test_node_role_exists() {
    local role
    role=$(aws iam get-role \
        --role-name "craftify-eks-node-role" \
        --query "Role.RoleName" \
        --output text 2>/dev/null || echo "")

    if [ -z "$role" ] || [ "$role" == "None" ]; then
        print_status "failed" "Lab Failed: IAM role 'craftify-eks-node-role' does not exist. Create it with EC2 trust policy."
        exit 1
    fi
    print_status "success" "Lab Passed: IAM role 'craftify-eks-node-role' exists."
}

function test_node_role_policies() {
    local policies
    policies=$(aws iam list-attached-role-policies \
        --role-name "craftify-eks-node-role" \
        --query "AttachedPolicies[*].PolicyName" \
        --output text 2>/dev/null || echo "")

    for required in "AmazonEKSWorkerNodePolicy" "AmazonEC2ContainerRegistryReadOnly" "AmazonEKS_CNI_Policy"; do
        if ! echo "$policies" | grep -q "$required"; then
            print_status "failed" "Lab Failed: IAM role 'craftify-eks-node-role' is missing '$required' policy."
            exit 1
        fi
    done
    print_status "success" "Lab Passed: All required managed policies are attached to the node role."
}

function test_s3_inline_policy() {
    load_config

    local inline_policies
    inline_policies=$(aws iam list-role-policies \
        --role-name "craftify-eks-node-role" \
        --query "PolicyNames" \
        --output text 2>/dev/null || echo "")

    if [ -z "$inline_policies" ]; then
        print_status "failed" "Lab Failed: No inline policy found on 'craftify-eks-node-role'. Add an inline policy granting s3:GetObject on the S3 bucket."
        exit 1
    fi

    local found=false
    for policy in $inline_policies; do
        local doc
        doc=$(aws iam get-role-policy \
            --role-name "craftify-eks-node-role" \
            --policy-name "$policy" \
            --query "PolicyDocument" \
            --output json 2>/dev/null || echo "")
        if echo "$doc" | grep -q "s3:GetObject" && echo "$doc" | grep -q "$BUCKET_NAME"; then
            found=true
            break
        fi
    done

    if [ "$found" == "false" ]; then
        print_status "failed" "Lab Failed: No inline policy grants s3:GetObject on bucket '$BUCKET_NAME'. Add one to 'craftify-eks-node-role'."
        exit 1
    fi
    print_status "success" "Lab Passed: Inline policy correctly grants s3:GetObject on the S3 bucket."
}

test_ecr_image_pushed
test_node_role_exists
test_node_role_policies
test_s3_inline_policy

print_status "success" "Lab Passed: ECR image is pushed and node IAM role is correctly configured with all required policies."
exit 0