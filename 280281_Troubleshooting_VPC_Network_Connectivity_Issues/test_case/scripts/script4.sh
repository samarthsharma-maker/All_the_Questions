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

function test_private_subnet_route_association() {
    local subnet1_rt subnet2_rt
    subnet1_rt=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$PRIVATE_SUBNET_1" --region "$REGION" --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)    
    subnet2_rt=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$PRIVATE_SUBNET_2" --region "$REGION" --query "RouteTables[0].RouteTableId" --output text 2>/dev/null)
    
    if [ "$subnet1_rt" != "$PRIVATE_RT" ] || [ "$subnet2_rt" != "$PRIVATE_RT" ]; then
        print_status "failed" "Test 7 Failed: Private Subnets not correctly associated with Private Route Table ($PRIVATE_RT)"
        exit 1
    fi
    
    print_status "success" "Test 7 Passed: Private Subnets correctly associated with Private Route Table"
}

function test_alb_connectivity() {
    
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "http://$ALB_DNS" 2>/dev/null || echo "000")
    
    if [ "$http_code" == "000" ]; then
        print_status "failed" "Test 8 Failed: Cannot reach ALB (connection timeout). Check security groups and route tables."
        exit 1
    elif [ "$http_code" == "503" ]; then
        print_status "success" "Test 8 Passed: ALB is reachable (HTTP $http_code - no healthy targets, as expected)"
    elif [ "$http_code" == "200" ]; then
        print_status "success" "Test 8 Passed: ALB is reachable (HTTP $http_code)"
    else
        print_status "success" "Test 8 Passed: ALB is reachable (HTTP $http_code)"
    fi
}

test_private_subnet_route_association
test_alb_connectivity
print_status "success" "Lab Passed: Subnet associations and ALB connectivity verified successfully."
exit 0
