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

function test_container_port_mapping() {    
    local container_port
    container_port=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" --query 'taskDefinition.containerDefinitions[0].portMappings[0].containerPort' --output text 2>/dev/null || echo "")
    
    if [ "$container_port" == "8080" ]; then
        print_status "success" "Test 10 Passed: Container port mapping set to 8080"
        return 0
    else
        print_status "failed" "Test 10 Failed: Container port is $container_port (expected: 8080)"
        return 1
    fi
}

function test_container_environment_variables() {
    local env_vars
    env_vars=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" --query 'taskDefinition.containerDefinitions[0].environment' --output json 2>/dev/null || echo "[]")
    
    local has_environment=$(echo "$env_vars" | jq -r '.[] | select(.name=="ENVIRONMENT") | .value' 2>/dev/null || echo "")
    local has_service_name=$(echo "$env_vars" | jq -r '.[] | select(.name=="SERVICE_NAME") | .value' 2>/dev/null || echo "")
    
    if [ "$has_environment" == "production" ] && [ "$has_service_name" == "payment-processor" ]; then
        print_status "success" "Test 11 Passed: Container has required environment variables"
        return 0
    else
        print_status "failed" "Test 11 Failed: Container missing required environment variables (ENVIRONMENT=production, SERVICE_NAME=payment-processor)"
        return 1
    fi
}

function test_cloudwatch_logs_config() {
    local log_driver
    local log_group_name
    
    log_driver=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" --query 'taskDefinition.containerDefinitions[0].logConfiguration.logDriver' --output text 2>/dev/null || echo "")
    log_group_name=$(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" --query 'taskDefinition.containerDefinitions[0].logConfiguration.options."awslogs-group"' --output text 2>/dev/null || echo "")
    
    if [ "$log_driver" == "awslogs" ] && [ "$log_group_name" == "$LOG_GROUP" ]; then
        print_status "success" "Test 12 Passed: CloudWatch Logs configured correctly"
        return 0
    else
        print_status "failed" "Test 12 Failed: Log driver is '$log_driver', log group is '$log_group_name' (expected: awslogs, $LOG_GROUP)"
        return 1
    fi
}

test_container_port_mapping
test_container_environment_variables
test_cloudwatch_logs_config
print_status "success" "Lab Passed: Container port mapping, environment variables, and CloudWatch Logs verified successfully."
exit 0
