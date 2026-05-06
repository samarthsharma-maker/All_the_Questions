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


function test_ecs_cluster_exists() {
    local cluster_status
    cluster_status=$(aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$REGION" --query 'clusters[0].status' --output text 2>/dev/null || echo "")
    
    if [ "$cluster_status" == "ACTIVE" ]; then
        print_status "success" "Test 1 Passed: ECS cluster '$CLUSTER_NAME' exists and is ACTIVE"
        return 0
    else
        print_status "failed" "Test 1 Failed: ECS cluster '$CLUSTER_NAME' not found or not ACTIVE"
        return 1
    fi
}

function test_task_definition_exists() {
    local task_def_arn
    task_def_arn=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" --query 'taskDefinition.taskDefinitionArn' --output text 2>/dev/null || echo "")
    
    if [ -n "$task_def_arn" ] && [ "$task_def_arn" != "None" ]; then
        print_status "success" "Test 2 Passed: Task definition '$TASK_FAMILY' exists"
        return 0
    else
        print_status "failed" "Test 2 Failed: Task definition '$TASK_FAMILY' not found"
        return 1
    fi
}

function test_task_definition_fargate() {
    local requires_compatibilities
    requires_compatibilities=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" --query 'taskDefinition.requiresCompatibilities' --output json 2>/dev/null || echo "[]")
    
    if echo "$requires_compatibilities" | grep -q "FARGATE"; then
        print_status "success" "Test 3 Passed: Task definition requires FARGATE compatibility"
        return 0
    else
        print_status "failed" "Test 3 Failed: Task definition missing FARGATE in requiresCompatibilities"
        return 1
    fi
}

test_ecs_cluster_exists
test_task_definition_exists
test_task_definition_fargate
print_status "success" "Preliminary Tests Passed: ECS cluster and task definition existence verified."
exit 0

