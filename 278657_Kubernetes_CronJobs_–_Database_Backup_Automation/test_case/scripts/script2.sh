#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="datastore-prod"
CRONJOB="database-backup"

function test_history_limits() {
    local successful_limit failed_limit
    
    successful_limit=$(kubectl get cronjob "$CRONJOB" -n "$NAMESPACE" -o jsonpath='{.spec.successfulJobsHistoryLimit}')
    failed_limit=$(kubectl get cronjob "$CRONJOB" -n "$NAMESPACE" -o jsonpath='{.spec.failedJobsHistoryLimit}')
    
    if [ "$successful_limit" != "3" ]; then
        print_status "failed" "Lab Failed: successfulJobsHistoryLimit should be 3 (found: $successful_limit)."
        exit 1
    fi
    
    if [ "$failed_limit" != "1" ]; then
        print_status "failed" "Lab Failed: failedJobsHistoryLimit should be 1 (found: $failed_limit)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Job history limits are correct (successful: 3, failed: 1)."
}


function test_concurrency_policy() {
    local policy
    policy=$(kubectl get cronjob "$CRONJOB" -n "$NAMESPACE" -o jsonpath='{.spec.concurrencyPolicy}')
    
    if [ "$policy" != "Forbid" ]; then
        print_status "failed" "Lab Failed: concurrencyPolicy should be 'Forbid' (found: '$policy')."
        exit 1
    fi
    
    print_status "success" "Lab Passed: concurrencyPolicy is 'Forbid' (prevents concurrent jobs)."
}

test_history_limits
test_concurrency_policy

print_status "success" "Lab Passed: CronJob configuration verification completed successfully."
exit 0