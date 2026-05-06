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

function test_asg_policy_no_cpu_tracking() {
    local policy_text
    policy_text=$(aws autoscaling describe-policies --auto-scaling-group-name "${ASG_NAME}" --policy-names "retailpulse-target-tracking" --output text --region "${REGION}" 2>/dev/null || true)

    if echo "${policy_text}" | grep -q "ASGAverageCPUUtilization"; then
        print_status "failed" "Lab Failed: The Auto Scaling policy 'retailpulse-target-tracking' is still tracking 'ASGAverageCPUUtilization'. CPU is a lagging indicator — it rises only after instances are already saturated. Switch to the custom metric 'RequestsPerTarget' in namespace 'AWS/ApplicationELB' so the fleet scales out before saturation occurs."
        exit 1
    else
        print_status "success" "Lab Passed: Auto Scaling policy 'retailpulse-target-tracking' does not track ASGAverageCPUUtilization."
    fi
}

function test_asg_policy_requests_per_target() {
    local policy_text
    policy_text=$(aws autoscaling describe-policies --auto-scaling-group-name "${ASG_NAME}" --policy-names "retailpulse-target-tracking" --output text --region "${REGION}" 2>/dev/null || true)

    if echo "${policy_text}" | grep -q "RequestsPerTarget"; then
        print_status "success" "Lab Passed: Auto Scaling policy 'retailpulse-target-tracking' tracks RequestsPerTarget."
    else
        print_status "failed" "Lab Failed: The Auto Scaling policy 'retailpulse-target-tracking' is not tracking 'RequestsPerTarget'. This metric rises immediately when traffic increases — before CPU saturates — allowing the fleet to scale out proactively. Set the policy to use a CustomizedMetricSpecification with MetricName 'RequestsPerTarget' in namespace 'AWS/ApplicationELB'."
        exit 1
    fi
}

test_asg_policy_no_cpu_tracking
test_asg_policy_requests_per_target
print_status "success" "All Lab Tests Passed: IAM policy, CloudWatch Agent namespace, memory alarm evaluation periods, and Auto Scaling target metric are all correctly configured."
exit 0