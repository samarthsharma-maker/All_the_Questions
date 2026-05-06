#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

function load_config() {
    local config="/home/user/craftify-deploy-lab/lab-config.txt"
    if [ ! -f "$config" ]; then
        print_status "failed" "Lab Failed: Lab config not found. Run the setup script first."
        exit 1
    fi
    source "$config"
}

function test_successful_deployment_exists() {
    load_config

    local status
    status=$(aws deploy list-deployments \
        --application-name "$APP_NAME" \
        --deployment-group-name "$DG_NAME" \
        --include-only-statuses Succeeded \
        --region "$REGION" \
        --query "deployments[0]" \
        --output text 2>/dev/null || echo "")

    if [ -z "$status" ] || [ "$status" == "None" ]; then
        print_status "failed" "Lab Failed: No successful deployment found for '$APP_NAME'. Start the CodeDeploy agent on the instance and re-trigger the pipeline."
        exit 1
    fi
    print_status "success" "Lab Passed: A successful deployment exists for '$APP_NAME'."
}

function test_pipeline_succeeded() {
    load_config

    local pipeline_status
    pipeline_status=$(aws codepipeline get-pipeline-state \
        --name "$PIPELINE_NAME" \
        --region "$REGION" \
        --query "stageStates[?stageName=='Deploy'].actionStates[0].latestExecution.status" \
        --output text 2>/dev/null || echo "")

    if [ "$pipeline_status" != "Succeeded" ]; then
        print_status "failed" "Lab Failed: Pipeline Deploy stage status is '$pipeline_status'. Re-trigger the pipeline after starting the CodeDeploy agent and wait for it to complete."
        exit 1
    fi
    print_status "success" "Lab Passed: Pipeline Deploy stage has succeeded."
}

test_successful_deployment_exists
test_pipeline_succeeded

print_status "success" "Lab Passed: CodeDeploy deployment succeeded and pipeline completed successfully."
exit 0