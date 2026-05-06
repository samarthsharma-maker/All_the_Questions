#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

REGION="us-west-2"
EC2_ROLE="retailpulse-ec2-role"
POLICY_NAME="retailpulse-cloudwatch-policy"
ASG_NAME="retailpulse-app-asg"
BASE_DIR="/home/user/retailpulse-lab"
CORRECT_NAMESPACE="RetailPulse/AppMetrics"


function test_iam_put_metric_data() {
    local policy_text
    policy_text=$(aws iam get-role-policy --role-name "${EC2_ROLE}" --policy-name "${POLICY_NAME}" --query 'PolicyDocument' --output text 2>/dev/null || true)

    if echo "${policy_text}" | grep -q "cloudwatch:PutMetricData"; then
        print_status "success" "Lab Passed: IAM inline policy '${POLICY_NAME}' includes cloudwatch:PutMetricData."
    else
        print_status "failed" "Lab Failed: The inline policy '${POLICY_NAME}' on role '${EC2_ROLE}' is missing 'cloudwatch:PutMetricData'. The CloudWatch Agent collects memory and disk metrics inside the OS but uses this API action to publish them. Without it the agent runs silently and no metrics appear in CloudWatch dashboards or alarms."
        exit 1
    fi
}


function test_iam_describe_volumes_retained() {
    local policy_text
    policy_text=$(aws iam get-role-policy --role-name "${EC2_ROLE}" --policy-name "${POLICY_NAME}" --query 'PolicyDocument' --output text 2>/dev/null || true)

    if echo "${policy_text}" | grep -q "ec2:DescribeVolumes"; then
        print_status "success" "Lab Passed: IAM inline policy retains ec2:DescribeVolumes."
    else
        print_status "failed" "Lab Failed: The inline policy '${POLICY_NAME}' is missing 'ec2:DescribeVolumes'. This action is required for the CloudWatch Agent to discover attached EBS volumes and collect disk space metrics. Do not remove existing permissions when adding new ones."
        exit 1
    fi
}

test_iam_put_metric_data
test_iam_describe_volumes_retained
print_status "success" "Lab Passed: IAM inline policy contains cloudwatch:PutMetricData and retains ec2:DescribeVolumes."
exit 0
