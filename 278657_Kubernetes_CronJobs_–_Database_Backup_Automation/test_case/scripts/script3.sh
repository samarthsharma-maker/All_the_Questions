#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="datastore-prod"
CRONJOB="database-backup"

function test_backoff_and_restart() {
    local backoff_limit restart_policy
    
    backoff_limit=$(kubectl get cronjob "$CRONJOB" -n "$NAMESPACE" -o jsonpath='{.spec.jobTemplate.spec.backoffLimit}')
    restart_policy=$(kubectl get cronjob "$CRONJOB" -n "$NAMESPACE" -o jsonpath='{.spec.jobTemplate.spec.template.spec.restartPolicy}')
    
    if [ "$backoff_limit" != "3" ]; then
        print_status "failed" "Lab Failed: backoffLimit should be 3 (found: $backoff_limit)."
        exit 1
    fi
    
    if [ "$restart_policy" != "OnFailure" ] && [ "$restart_policy" != "Never" ]; then
        print_status "failed" "Lab Failed: restartPolicy should be 'OnFailure' or 'Never' (found: '$restart_policy')."
        exit 1
    fi
    
    print_status "success" "Lab Passed: backoffLimit is 3 and restartPolicy is correct."
}

function test_manual_job_execution() {
    local test_job="database-backup-test-$(date +%s)"
    
    # Clean up any existing test jobs
    kubectl delete job -n "$NAMESPACE" -l app=database-backup --ignore-not-found=true &>/dev/null
    
    # Create manual job from CronJob
    if ! kubectl create job "$test_job" --from=cronjob/"$CRONJOB" -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: Could not create test job from CronJob."
        exit 1
    fi
    
    # Wait for job to complete (max 60 seconds)
    local completed=false
    for i in {1..60}; do
        job_status=$(kubectl get job "$test_job" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null)
        
        if [ "$job_status" == "True" ]; then
            completed=true
            break
        fi
        
        sleep 1
    done
    
    # Clean up test job
    kubectl delete job "$test_job" -n "$NAMESPACE" --ignore-not-found=true &>/dev/null
    
    if [ "$completed" != "true" ]; then
        print_status "failed" "Lab Failed: Test job did not complete successfully within 60 seconds."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Manual job created and completed successfully."
}

test_backoff_and_restart
test_manual_job_execution

print_status "success" "Lab Passed: All tests completed successfully. CronJob is properly configured!"
exit 0