#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

REGION="us-west-2"

if [ -f /tmp/network_env.txt ]; then
    source /tmp/network_env.txt
else
    print_status "failed" "Environment file not found. Setup may not have completed."
    exit 1
fi

function test_alb_security_group_http_inbound() {
    local http_rule
    http_rule=$(aws ec2 describe-security-groups --group-ids "$ALB_SG" --region "$REGION" --output text --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\` && ToPort==\`80\` && IpProtocol==\`tcp\`].IpRanges[] | [?CidrIp==\`0.0.0.0/0\`] | [0]" --output text 2>/dev/null)
    
    if [ -z "$http_rule" ] || [ "$http_rule" == "None" ]; then
        print_status "failed" "Test 1 Failed: ALB Security Group ($ALB_SG) missing HTTP (port 80) inbound rule from 0.0.0.0/0"
        exit 1
    fi
    
    print_status "success" "Test 1 Passed: ALB Security Group allows HTTP (port 80) from internet (0.0.0.0/0)"
}

function test_webserver_security_group_alb_inbound() {
    local alb_rule
    alb_rule=$(aws ec2 describe-security-groups --group-ids "$WEB_SG" --region "$REGION" --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\` && ToPort==\`80\` && IpProtocol==\`tcp\`].UserIdGroupPairs[] | [?GroupId==\`$ALB_SG\`] | [0]" --output text 2>/dev/null)    
    if [ -z "$alb_rule" ] || [ "$alb_rule" == "None" ]; then
        print_status "failed" "Test 2 Failed: Web Server Security Group ($WEB_SG) missing HTTP (port 80) inbound from ALB Security Group ($ALB_SG)"
        exit 1
    fi
    
    print_status "success" "Test 2 Passed: Web Server Security Group allows HTTP (port 80) from ALB Security Group"
}

test_alb_security_group_http_inbound
test_webserver_security_group_alb_inbound
print_status "success" "Lab Passed: Security Group rules verified successfully."
exit 0
