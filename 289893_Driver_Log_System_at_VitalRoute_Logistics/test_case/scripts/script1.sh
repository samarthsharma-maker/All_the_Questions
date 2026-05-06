#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

REGION="us-west-2"

function load_config() {
    local config="/home/user/vitalroute-efs-lab/lab-config.txt"
    if [ ! -f "$config" ]; then
        print_status "failed" "Lab Failed: Lab config file not found. Run the setup script first."
        exit 1
    fi
    source "$config"
}

function test_efs_sg_has_no_cidr_rule() {
    load_config

    local cidr_rule
    cidr_rule=$(aws ec2 describe-security-groups \
        --group-ids "$EFS_SG_ID" \
        --region "$REGION" \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`2049\`].IpRanges[*].CidrIp" \
        --output text 2>/dev/null || echo "")

    if [ -n "$cidr_rule" ] && [ "$cidr_rule" != "None" ]; then
        print_status "failed" "Lab Failed: EFS security group still allows port 2049 from CIDR '$cidr_rule'. Remove this rule and replace it with a rule allowing port 2049 from the EC2 security group ID."
        exit 1
    fi
    print_status "success" "Lab Passed: VPC CIDR rule has been removed from the EFS security group."
}

function test_efs_sg_allows_ec2_sg() {
    load_config

    local sg_source
    sg_source=$(aws ec2 describe-security-groups \
        --group-ids "$EFS_SG_ID" \
        --region "$REGION" \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`2049\`].UserIdGroupPairs[*].GroupId" \
        --output text 2>/dev/null || echo "")

    if [ -z "$sg_source" ] || [ "$sg_source" == "None" ]; then
        print_status "failed" "Lab Failed: EFS security group has no inbound rule for port 2049 from a security group source. Add a rule allowing port 2049 from '$EC2_SG_ID'."
        exit 1
    fi

    if [ "$sg_source" != "$EC2_SG_ID" ]; then
        print_status "failed" "Lab Failed: EFS security group allows port 2049 from '$sg_source' instead of the EC2 security group '$EC2_SG_ID'."
        exit 1
    fi

    print_status "success" "Lab Passed: EFS security group correctly allows port 2049 from the EC2 security group."
}

test_efs_sg_has_no_cidr_rule
test_efs_sg_allows_ec2_sg

print_status "success" "Lab Passed: EFS security group is correctly configured to allow NFS traffic from the EC2 security group only."
exit 0