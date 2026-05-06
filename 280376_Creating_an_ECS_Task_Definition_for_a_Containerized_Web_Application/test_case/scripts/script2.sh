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



function test_task_definition_network_mode() {    
    local network_mode
    network_mode=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" --query 'taskDefinition.networkMode' --output text 2>/dev/null || echo "")
    
    if [ "$network_mode" == "awsvpc" ]; then
        print_status "success" "Test 4 Passed: Task definition uses 'awsvpc' network mode"
        return 0
    else
        print_status "failed" "Test 4 Failed: Task definition network mode is '$network_mode' (expected: awsvpc)"
        return 1
    fi
}
function test_task_definition_cpu_memory() {
    local cpu memory
    
    cpu=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" --query 'taskDefinition.cpu' --output text 2>/dev/null || echo "")    
    memory=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" --query 'taskDefinition.memory' --output text 2>/dev/null || echo "")
    
    if [ "$cpu" == "256" ] && [ "$memory" == "512" ]; then
        print_status "success" "Test 5 Passed: Task definition has CPU=256 and Memory=512"
        return 0
    else
        print_status "failed" "Test 5 Failed: Task definition has CPU=$cpu, Memory=$memory (expected: CPU=256, Memory=512)"
        return 1
    fi
}

function test_task_execution_role() {
    local execution_role_arn
    execution_role_arn=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" --query 'taskDefinition.executionRoleArn' --output text 2>/dev/null || echo "")
    
    if [[ "$execution_role_arn" == *"PaymentProcessorExecutionRole"* ]]; then
        print_status "success" "Test 6 Passed: Task definition has execution role attached"
        return 0
    else
        print_status "failed" "Test 6 Failed: Task definition missing PaymentProcessorExecutionRole"
        return 1
    fi
}

test_task_definition_network_mode
test_task_definition_cpu_memory
test_task_execution_role
print_status "success" "Lab Passed: Task definition CPU/Memory and execution role verified successfully."
exit 0

