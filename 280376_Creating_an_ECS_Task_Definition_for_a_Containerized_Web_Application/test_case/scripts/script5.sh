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

function test_ecs_service_exists() {
    local service_status
    service_status=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$REGION" --query 'services[0].status' --output text 2>/dev/null || echo "")
    
    if [ "$service_status" == "ACTIVE" ]; then
        print_status "success" "Test 13 Passed: ECS service '$SERVICE_NAME' exists and is ACTIVE"
        return 0
    else
        print_status "failed" "Test 13 Failed: ECS service '$SERVICE_NAME' not found or not ACTIVE"
        return 1
    fi
}

function test_service_running_tasks() {
    local running_count desired_count
    
    running_count=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$REGION" --query 'services[0].runningCount' --output text 2>/dev/null || echo "0")
    desired_count=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$REGION" --query 'services[0].desiredCount' --output text 2>/dev/null || echo "0")
    
    if [ "$running_count" -eq "$desired_count" ] && [ "$running_count" -gt 0 ]; then
        print_status "success" "Test 14 Passed: Service has $running_count running task(s) matching desired count"
        return 0
    else
        print_status "failed" "Test 14 Failed: Running count is $running_count, desired count is $desired_count"
        return 1
    fi
}

function test_task_health() {
    local task_arn
    task_arn=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --service-name "$SERVICE_NAME" --desired-status RUNNING --region "$REGION" --query 'taskArns[0]' --output text 2>/dev/null || echo "")
    
    if [ -z "$task_arn" ] || [ "$task_arn" == "None" ]; then
        print_status "failed" "Test 15 Failed: No running tasks found"
        return 1
    fi
    
    local last_status health_status
    
    last_status=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$task_arn" --region "$REGION" --query 'tasks[0].lastStatus' --output text 2>/dev/null || echo "")
    health_status=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$task_arn" --region "$REGION" --query 'tasks[0].healthStatus' --output text 2>/dev/null || echo "UNKNOWN")
    
    if [ "$last_status" == "RUNNING" ] && { [ "$health_status" == "HEALTHY" ] || [ "$health_status" == "UNKNOWN" ]; }; then
        print_status "success" "Test 15 Passed: Task is RUNNING and healthy"
        return 0
    else
        print_status "failed" "Test 15 Failed: Task status is $last_status, health is $health_status"
        return 1
    fi
}

test_ecs_service_exists
test_service_running_tasks
test_task_health
print_status "success" "Final Tests Passed: ECS service and task health verified."
exit 0
