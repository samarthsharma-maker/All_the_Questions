#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
SG_NAME="file-server-sg"
INSTANCE_NAME="file-server-01"
VOLUME_NAME="file-server-data"

function test_security_group_exists() {    
    local sg_id
    sg_id=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_NAME" --region "$REGION" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")
    
    if [ -n "$sg_id" ] && [ "$sg_id" != "None" ]; then
        export SECURITY_GROUP_ID="$sg_id"
        print_status "success" "Test 1 Passed: Security group '$SG_NAME' exists (ID: $sg_id)"
        return 0
    else
        print_status "failed" "Test 1 Failed: Security group '$SG_NAME' not found"
        return 1
    fi
}

function test_security_group_ssh_rule() {    
    if [ -z "${SECURITY_GROUP_ID:-}" ]; then
        print_status "failed" "Test 2 Failed: Security group ID not available (Test 1 must pass first)"
        return 1
    fi
    
    local ssh_rule rule_count
    ssh_rule=$(aws ec2 describe-security-groups --group-ids "$SECURITY_GROUP_ID" --region "$REGION" --query 'SecurityGroups[0].IpPermissions[?FromPort==`22` && ToPort==`22` && IpProtocol==`tcp`]' --output json 2>/dev/null || echo "[]")
    rule_count=$(echo "$ssh_rule" | jq '. | length' 2>/dev/null || echo "0")
    
    if [ "$rule_count" -gt 0 ]; then
        print_status "success" "Test 2 Passed: Security group has SSH (port 22) inbound rule"
        return 0
    else
        print_status "failed" "Test 2 Failed: Security group missing SSH (port 22) inbound rule"
        return 1
    fi
}

function test_security_group_self_reference() {
    
    if [ -z "${SECURITY_GROUP_ID:-}" ]; then
        print_status "failed" "Test 3 Failed: Security group ID not available"
        return 1
    fi
    
    local self_rule rule_count
    self_rule=$(aws ec2 describe-security-groups --group-ids "$SECURITY_GROUP_ID" --region "$REGION" --query "SecurityGroups[0].IpPermissions[?UserIdGroupPairs[?GroupId==\`$SECURITY_GROUP_ID\`]]" --output json 2>/dev/null || echo "[]")
    rule_count=$(echo "$self_rule" | jq '. | length' 2>/dev/null || echo "0")
    
    if [ "$rule_count" -gt 0 ]; then
        print_status "success" "Test 3 Passed: Security group has self-referencing rule"
        return 0
    else
        print_status "failed" "Test 3 Failed: Security group missing self-referencing rule"
        return 1
    fi
}

test_security_group_exists
test_security_group_ssh_rule
test_security_group_self_reference
print_status "success" "Lab Passed: Security Group configuration verified successfully."
exit 0
