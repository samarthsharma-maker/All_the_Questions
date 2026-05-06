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

function test_public_route_table_igw_route() {    
    local igw_route
    igw_route=$(aws ec2 describe-route-tables --route-table-ids "$PUBLIC_RT" --region "$REGION" --query "RouteTables[0].Routes[?DestinationCidrBlock==\`0.0.0.0/0\` && GatewayId==\`$IGW_ID\`] | [0]" --output text 2>/dev/null)
    
    if [ -z "$igw_route" ] || [ "$igw_route" == "None" ]; then
        print_status "failed" "Test 3 Failed: Public Route Table ($PUBLIC_RT) missing route 0.0.0.0/0 -> $IGW_ID"
        exit 1
    fi
    
    print_status "success" "Test 3 Passed: Public Route Table has route to Internet Gateway (0.0.0.0/0 -> $IGW_ID)"
}

function test_private_route_table_nat_route() {
    local nat_route
    nat_route=$(aws ec2 describe-route-tables --route-table-ids "$PRIVATE_RT" --region "$REGION" --query "RouteTables[0].Routes[?DestinationCidrBlock==\`0.0.0.0/0\` && NatGatewayId==\`$NAT_GW_ID\`] | [0]" --output text 2>/dev/null)
    
    if [ -z "$nat_route" ] || [ "$nat_route" == "None" ]; then
        print_status "failed" "Test 4 Failed: Private Route Table ($PRIVATE_RT) missing route 0.0.0.0/0 -> $NAT_GW_ID"
        exit 1
    fi
    
    print_status "success" "Test 4 Passed: Private Route Table has route to NAT Gateway (0.0.0.0/0 -> $NAT_GW_ID)"
}

test_public_route_table_igw_route
test_private_route_table_nat_route
print_status "success" "Lab Passed: Route Table routes verified successfully."
exit 0
