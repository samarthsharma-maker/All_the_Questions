#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME="production-cluster"
TASK_FAMILY="payment-processor-task"
SERVICE_NAME="payment-processor-service"
ECR_REPO="payment-processor"
LOG_GROUP="/ecs/payment-processor"

function test_task_role() {
    local task_role_arn
    task_role_arn=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" --query 'taskDefinition.taskRoleArn' --output text 2>/dev/null || echo "")
    
    if [[ "$task_role_arn" == *"PaymentProcessorTaskRole"* ]]; then
        print_status "success" "Test 7 Passed: Task definition has task role attached"
        return 0
    else
        print_status "failed" "Test 7 Failed: Task definition missing PaymentProcessorTaskRole"
        return 1
    fi
}

function test_container_definition() {
    local container_name
    container_name=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" --query 'taskDefinition.containerDefinitions[0].name' --output text 2>/dev/null || echo "")
    
    if [ "$container_name" == "payment-processor" ]; then
        print_status "success" "Test 8 Passed: Container definition 'payment-processor' exists"
        return 0
    else
        print_status "failed" "Test 8 Failed: Container name is '$container_name' (expected: payment-processor)"
        return 1
    fi
}

function test_container_image() {    
    local image_uri
    image_uri=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" --query 'taskDefinition.containerDefinitions[0].image' --output text 2>/dev/null || echo "")
    
    if [[ "$image_uri" == *"$ECR_REPO"* ]]; then
        print_status "success" "Test 9 Passed: Container uses ECR image from $ECR_REPO repository"
        return 0
    else
        print_status "failed" "Test 9 Failed: Container image '$image_uri' doesn't reference $ECR_REPO"
        return 1
    fi
}

test_task_role
test_container_definition
test_container_image
print_status "success" "Lab Passed: Task role and container definition verified successfully."
exit 0
