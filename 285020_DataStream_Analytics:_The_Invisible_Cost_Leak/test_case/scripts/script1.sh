#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

REGION="us-west-2"

ASG_NAME="datastream-worker-asg"
LOG_GROUP="/aws/datastream/processor"
INSTANCE_NAME="datastream-dev-debug"

############################################################
# Test 1 — Auto Scaling configuration
############################################################

function test_asg_configuration() {

MIN_SIZE=$(aws autoscaling describe-auto-scaling-groups \
--auto-scaling-group-names "${ASG_NAME}" \
--region "${REGION}" \
--query 'AutoScalingGroups[0].MinSize' \
--output text 2>/dev/null)

DESIRED=$(aws autoscaling describe-auto-scaling-groups \
--auto-scaling-group-names "${ASG_NAME}" \
--region "${REGION}" \
--query 'AutoScalingGroups[0].DesiredCapacity' \
--output text 2>/dev/null)

MAX_SIZE=$(aws autoscaling describe-auto-scaling-groups \
--auto-scaling-group-names "${ASG_NAME}" \
--region "${REGION}" \
--query 'AutoScalingGroups[0].MaxSize' \
--output text 2>/dev/null)

if [[ "${MIN_SIZE}" == "0" && "${DESIRED}" == "0" && "${MAX_SIZE}" -le "5" ]]; then
    print_status "success" "Lab Passed: Auto Scaling group '${ASG_NAME}' is configured correctly (Min=0, Desired=0, Max≤5)."
else
    print_status "failed" "Lab Failed: Auto Scaling group '${ASG_NAME}' is misconfigured. The correct configuration should be Min=0, Desired=0, and Max≤5 so worker instances do not run continuously and incur unnecessary cost."
    exit 1
fi

}

############################################################
# Test 2 — S3 lifecycle policy
############################################################

function test_s3_lifecycle_rule() {

BUCKET=$(aws s3api list-buckets \
--query 'Buckets[?contains(Name, `datastream-temp-results`)].Name' \
--output text)

if [ -z "${BUCKET}" ]; then
    print_status "failed" "Lab Failed: Could not locate the S3 bucket used for temporary analytics results."
    exit 1
fi

EXPIRATION=$(aws s3api get-bucket-lifecycle-configuration \
--bucket "${BUCKET}" \
--query 'Rules[0].Expiration.Days' \
--output text 2>/dev/null)

if [[ "${EXPIRATION}" == "7" ]]; then
    print_status "success" "Lab Passed: S3 lifecycle rule deletes objects after 7 days in bucket '${BUCKET}'."
else
    print_status "failed" "Lab Failed: Bucket '${BUCKET}' does not have the required lifecycle rule to delete objects after 7 days. Temporary analytics outputs should automatically expire to prevent storage costs from growing indefinitely."
    exit 1
fi

}

############################################################
# Test 3 — CloudWatch log retention
############################################################

function test_log_retention() {

RETENTION=$(aws logs describe-log-groups \
--log-group-name-prefix "${LOG_GROUP}" \
--query 'logGroups[0].retentionInDays' \
--output text \
--region "${REGION}" 2>/dev/null)

if [[ "${RETENTION}" == "14" ]]; then
    print_status "success" "Lab Passed: Log group '${LOG_GROUP}' retention period is correctly set to 14 days."
else
    print_status "failed" "Lab Failed: Log group '${LOG_GROUP}' does not have the correct retention policy. Logs should expire after 14 days to prevent unnecessary CloudWatch storage costs."
    exit 1
fi

}

############################################################
# Test 4 — Debug EC2 instance state
############################################################

function test_debug_instance_state() {

STATE=$(aws ec2 describe-instances \
--filters "Name=tag:Name,Values=${INSTANCE_NAME}" \
--query 'Reservations[].Instances[].State.Name' \
--output text \
--region "${REGION}" 2>/dev/null)

if [[ "${STATE}" == "stopped" || "${STATE}" == "terminated" ]]; then
    print_status "success" "Lab Passed: Debug EC2 instance '${INSTANCE_NAME}' is no longer running."
else
    print_status "failed" "Lab Failed: The debug EC2 instance '${INSTANCE_NAME}' is still running. This instance should be stopped or terminated to avoid unnecessary compute costs."
    exit 1
fi

}

############################################################
# Run tests
############################################################

test_asg_configuration
test_s3_lifecycle_rule
test_log_retention
test_debug_instance_state

print_status "success" "Lab Passed: All FinOps cost optimization issues have been successfully resolved."

exit 0