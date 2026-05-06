#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

function load_config() {
    local config="/home/user/craftify-cw-lab/lab-config.txt"
    if [ ! -f "$config" ]; then
        print_status "failed" "Lab Failed: Lab config not found. Run the setup script first."
        exit 1
    fi
    source "$config"
}

function test_metric_filter_exists() {
    load_config

    local filter_name
    filter_name=$(aws logs describe-metric-filters \
        --log-group-name "$LOG_GROUP" \
        --region "$REGION" \
        --query "metricFilters[0].filterName" \
        --output text 2>/dev/null || echo "")

    if [ -z "$filter_name" ] || [ "$filter_name" == "None" ]; then
        print_status "failed" "Lab Failed: No metric filter found on log group '$LOG_GROUP'. Create a metric filter that counts lines containing 'ERROR'."
        exit 1
    fi
    print_status "success" "Lab Passed: Metric filter '$filter_name' exists on the log group."
}

function test_metric_filter_targets_error() {
    load_config

    local filter_pattern
    filter_pattern=$(aws logs describe-metric-filters \
        --log-group-name "$LOG_GROUP" \
        --region "$REGION" \
        --query "metricFilters[0].filterPattern" \
        --output text 2>/dev/null || echo "")

    if ! echo "$filter_pattern" | grep -qi "ERROR"; then
        print_status "failed" "Lab Failed: Metric filter pattern is '$filter_pattern'. It must match 'ERROR' to count error log lines."
        exit 1
    fi
    print_status "success" "Lab Passed: Metric filter pattern correctly targets ERROR log lines."
}

function test_metric_filter_namespace() {
    load_config

    local namespace
    namespace=$(aws logs describe-metric-filters \
        --log-group-name "$LOG_GROUP" \
        --region "$REGION" \
        --query "metricFilters[0].metricTransformations[0].metricNamespace" \
        --output text 2>/dev/null || echo "")

    if [ -z "$namespace" ] || [ "$namespace" == "None" ]; then
        print_status "failed" "Lab Failed: Metric filter has no metric namespace configured. Set the namespace to 'Craftify/AppMetrics'."
        exit 1
    fi
    print_status "success" "Lab Passed: Metric filter writes to namespace '$namespace'."
}

test_metric_filter_exists
test_metric_filter_targets_error
test_metric_filter_namespace

print_status "success" "Lab Passed: Metric filter is correctly configured to count ERROR log lines."
exit 0