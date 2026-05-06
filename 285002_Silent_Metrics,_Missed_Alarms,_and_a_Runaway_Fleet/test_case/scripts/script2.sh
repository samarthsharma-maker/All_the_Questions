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

function test_agent_config_namespace() {
    local config_file="${BASE_DIR}/config.json"

    if [ ! -f "${config_file}" ]; then
        print_status "failed" "Lab Failed: CloudWatch Agent config not found at '${config_file}'. Ensure the config file exists and has been updated with the correct namespace '${CORRECT_NAMESPACE}'."
        exit 1
    fi

    if grep -q "\"${CORRECT_NAMESPACE}\"" "${config_file}"; then
        print_status "success" "Lab Passed: CloudWatch Agent config uses the correct namespace '${CORRECT_NAMESPACE}'."
    else
        print_status "failed" "Lab Failed: The CloudWatch Agent config at '${config_file}' does not use the correct namespace '${CORRECT_NAMESPACE}'. Metrics published to the wrong namespace are invisible to all dashboards and alarms. Update the 'namespace' field in config.json and restart the agent."
        exit 1
    fi
}

function test_agent_config_no_wrong_namespace() {
    local config_file="${BASE_DIR}/config.json"

    if grep -q '"RetailPulseMetrics"' "${config_file}" 2>/dev/null; then
        print_status "failed" "Lab Failed: The CloudWatch Agent config still contains the wrong namespace 'RetailPulseMetrics'. Replace it with '${CORRECT_NAMESPACE}' so metrics are published to the namespace that dashboards and alarms are watching."
        exit 1
    else
        print_status "success" "Lab Passed: CloudWatch Agent config no longer references the broken namespace 'RetailPulseMetrics'."
    fi
}

test_agent_config_namespace
test_agent_config_no_wrong_namespace
print_status "success" "Lab Passed: CloudWatch Agent config namespace is correctly set and does not contain the wrong namespace."
exit 0