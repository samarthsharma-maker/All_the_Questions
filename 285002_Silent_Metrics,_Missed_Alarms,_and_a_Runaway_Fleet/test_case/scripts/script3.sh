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

function test_memory_alarm_evaluation_periods() {
    local eval_periods
    eval_periods=$(aws cloudwatch describe-alarms --alarm-names "retailpulse-high-memory" --query 'MetricAlarms[0].EvaluationPeriods' --output text --region "${REGION}" 2>/dev/null || true)

    if [ "${eval_periods}" = "2" ]; then
        print_status "success" "Lab Passed: retailpulse-high-memory alarm EvaluationPeriods is correctly set to 2."
    else
        print_status "failed" "Lab Failed: The alarm 'retailpulse-high-memory' has EvaluationPeriods set to '${eval_periods:-MISSING}', expected '2'. With Period=300s and EvaluationPeriods=12 the alarm requires 60 consecutive minutes above threshold before firing — genuine memory spikes resolve long before the alarm triggers. Set EvaluationPeriods to 2 so the alarm fires after 10 minutes."
        exit 1
    fi
}

function test_memory_alarm_not_broken_periods() {
    local eval_periods
    eval_periods=$(aws cloudwatch describe-alarms --alarm-names "retailpulse-high-memory" --query 'MetricAlarms[0].EvaluationPeriods' --output text --region "${REGION}" 2>/dev/null || true)

    if [ "${eval_periods}" = "12" ]; then
        print_status "failed" "Lab Failed: The alarm 'retailpulse-high-memory' still has EvaluationPeriods=12 (60 minutes). This means a memory spike must last an entire hour before the alarm fires — short but severe spikes will never be detected. Change EvaluationPeriods to 2."
        exit 1
    else
        print_status "success" "Lab Passed: retailpulse-high-memory alarm no longer uses the broken EvaluationPeriods value of 12."
    fi
}

test_memory_alarm_evaluation_periods
test_memory_alarm_not_broken_periods
print_status "success" "Lab Passed: retailpulse-high-memory alarm has correct EvaluationPeriods and does not have the broken value."
exit 0