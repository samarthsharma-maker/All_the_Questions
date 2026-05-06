#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="datastore-prod"
CRONJOB="database-backup"

function test_cronjob_exists() {
    if ! kubectl get cronjob "$CRONJOB" -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: CronJob '$CRONJOB' does not exist in namespace '$NAMESPACE'."
        exit 1
    fi
    print_status "success" "Lab Passed: CronJob '$CRONJOB' exists."
}

function test_schedule() {
    local schedule
    schedule=$(kubectl get cronjob "$CRONJOB" -n "$NAMESPACE" -o jsonpath='{.spec.schedule}')
    
    if [ "$schedule" != "0 2 * * *" ]; then
        print_status "failed" "Lab Failed: Schedule is incorrect (expected: '0 2 * * *', found: '$schedule')."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Schedule is correct (0 2 * * * - runs at 2 AM UTC daily)."
}


# ==========================================
# Execute All Tests
# ==========================================
test_cronjob_exists
test_schedule


print_status "success" "Lab Passed: Basic CronJob existence and schedule verification completed successfully."
exit 0