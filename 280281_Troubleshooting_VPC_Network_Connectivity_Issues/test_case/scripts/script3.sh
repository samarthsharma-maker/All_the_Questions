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

function test_private_nacl_ephemeral_outbound() {
    local ephemeral_rule
    ephemeral_rule=$(aws ec2 describe-network-acls --network-acl-ids "$PRIVATE_NACL" --region "$REGION" --query "NetworkAcls[0].Entries[?Egress==\`true\` && RuleAction==\`allow\` && PortRange.From==\`1024\` && PortRange.To==\`65535\` && CidrBlock==\`10.0.0.0/16\`] | [0]" --output text 2>/dev/null)    
    if [ -z "$ephemeral_rule" ] || [ "$ephemeral_rule" == "None" ]; then
        print_status "failed" "Test 5 Failed: Private NACL ($PRIVATE_NACL) missing ephemeral port (1024-65535) outbound rule to 10.0.0.0/16"
        exit 1
    fi
    print_status "success" "Test 5 Passed: Private NACL has ephemeral port (1024-65535) outbound rule to VPC"
}

function test_public_subnet_route_association() {
    local subnet1_rt subnet2_rt
    subnet1_rt=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$PUBLIC_SUBNET_1" --region "$REGION" --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)
    subnet2_rt=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$PUBLIC_SUBNET_2" --region "$REGION" --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)
    
    if [ "$subnet1_rt" != "$PUBLIC_RT" ] || [ "$subnet2_rt" != "$PUBLIC_RT" ]; then
        print_status "failed" "Test 6 Failed: Public Subnets not correctly associated with Public Route Table ($PUBLIC_RT)"
        exit 1
    fi
    
    print_status "success" "Test 6 Passed: Public Subnets correctly associated with Public Route Table"
}

test_private_nacl_ephemeral_outbound
test_public_subnet_route_association
print_status "success" "Lab Passed: NACL and Route Table associations verified successfully."
exit 0
