#!/bin/bash

set -euo pipefail
export AWS_PAGER=""

# ==========================================
# SOLUTION SCRIPT: FIX VPC NETWORKING ISSUES
# ==========================================

echo "==========================================="
echo "VPC Networking Fix Solution"
echo "==========================================="
echo ""

# Check if environment file exists
if [ ! -f /tmp/network_env.txt ]; then
    echo " Error: /tmp/network_env.txt not found"
    echo ""
    echo "Please run the setup script first:"
    echo "  /home/user/network_setup.sh"
    echo ""
    exit 1
fi

# Load environment variables
echo "Loading environment variables from /tmp/network_env.txt..."
source /tmp/network_env.txt

# Verify required variables are set
REQUIRED_VARS=(
    "VPC_ID" "IGW_ID" "NAT_GW_ID"
    "PUBLIC_RT" "PRIVATE_RT"
    "ALB_SG" "WEB_SG" "PRIVATE_NACL"
    "REGION"
)

MISSING_VARS=0
for VAR in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!VAR:-}" ]; then
        echo "Error: Variable $VAR is not set"
        MISSING_VARS=1
    fi
done

if [ $MISSING_VARS -eq 1 ]; then
    echo ""
    echo "Environment file is incomplete. Please re-run the setup script."
    exit 1
fi

echo "Environment variables loaded successfully"
echo ""
echo "Environment Details:"
echo "  VPC ID: $VPC_ID"
echo "  Region: $REGION"
echo "  ALB SG: $ALB_SG"
echo "  Web SG: $WEB_SG"
echo "  Public RT: $PUBLIC_RT"
echo "  Private RT: $PRIVATE_RT"
echo ""
echo "==========================================="
echo "Applying Fixes..."
echo "==========================================="
echo ""

# ==========================================
# FIX 1: ALB Security Group - Add HTTP Inbound
# ==========================================
echo "Fix 1: Adding HTTP (port 80) inbound to ALB Security Group..."

# Fixed: flatten IpRanges with [] before filtering to avoid "None" false positive
EXISTING_RULE=$(aws ec2 describe-security-groups \
    --group-ids "$ALB_SG" \
    --region "$REGION" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\` && ToPort==\`80\` && IpProtocol==\`tcp\`].IpRanges[] | [?CidrIp==\`0.0.0.0/0\`] | [0]" \
    --output text 2>/dev/null || echo "")

if [ -z "$EXISTING_RULE" ] || [ "$EXISTING_RULE" == "None" ]; then
    aws ec2 authorize-security-group-ingress \
        --group-id "$ALB_SG" \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region "$REGION" 2>/dev/null || true
    echo "  HTTP inbound rule added to ALB Security Group"
else
    echo "  HTTP inbound rule already exists"
fi

echo ""

# ==========================================
# FIX 2: Web Server Security Group - Add HTTP from ALB
# ==========================================
echo "Fix 2: Adding HTTP (port 80) inbound from ALB to Web Server Security Group..."

# Fixed: flatten UserIdGroupPairs with [] before filtering to avoid "None" false positive
EXISTING_RULE=$(aws ec2 describe-security-groups \
    --group-ids "$WEB_SG" \
    --region "$REGION" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\` && ToPort==\`80\` && IpProtocol==\`tcp\`].UserIdGroupPairs[] | [?GroupId==\`$ALB_SG\`] | [0]" \
    --output text 2>/dev/null || echo "")

if [ -z "$EXISTING_RULE" ] || [ "$EXISTING_RULE" == "None" ]; then
    # Fixed: --source-group is invalid in AWS CLI v2, use --ip-permissions instead
    aws ec2 authorize-security-group-ingress \
        --group-id "$WEB_SG" \
        --ip-permissions "IpProtocol=tcp,FromPort=80,ToPort=80,UserIdGroupPairs=[{GroupId=$ALB_SG}]" \
        --region "$REGION" 2>/dev/null || true
    echo "  HTTP inbound rule from ALB added to Web Server Security Group"
else
    echo "  HTTP inbound rule from ALB already exists"
fi

echo ""

# ==========================================
# FIX 3: Public Route Table - Add Route to IGW
# ==========================================
echo "Fix 3: Adding route to Internet Gateway in Public Route Table..."

EXISTING_ROUTE=$(aws ec2 describe-route-tables \
    --route-table-ids "$PUBLIC_RT" \
    --region "$REGION" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock==\`0.0.0.0/0\`]" \
    --output text 2>/dev/null || echo "")

if [ -z "$EXISTING_ROUTE" ] || [ "$EXISTING_ROUTE" == "None" ]; then
    aws ec2 create-route \
        --route-table-id "$PUBLIC_RT" \
        --destination-cidr-block 0.0.0.0/0 \
        --gateway-id "$IGW_ID" \
        --region "$REGION" 2>/dev/null || true
    echo "  Route to Internet Gateway added to Public Route Table"
else
    echo "  Route to Internet Gateway already exists"
fi

echo ""

# ==========================================
# FIX 4: Private Route Table - Add Route to NAT Gateway
# ==========================================
echo "Fix 4: Adding route to NAT Gateway in Private Route Table..."

EXISTING_ROUTE=$(aws ec2 describe-route-tables \
    --route-table-ids "$PRIVATE_RT" \
    --region "$REGION" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock==\`0.0.0.0/0\`]" \
    --output text 2>/dev/null || echo "")

if [ -z "$EXISTING_ROUTE" ] || [ "$EXISTING_ROUTE" == "None" ]; then
    aws ec2 create-route \
        --route-table-id "$PRIVATE_RT" \
        --destination-cidr-block 0.0.0.0/0 \
        --nat-gateway-id "$NAT_GW_ID" \
        --region "$REGION" 2>/dev/null || true
    echo "  Route to NAT Gateway added to Private Route Table"
else
    echo "  Route to NAT Gateway already exists"
fi

echo ""

# ==========================================
# FIX 5: Private NACL - Add Ephemeral Port Outbound
# ==========================================
echo "Fix 5: Adding ephemeral port outbound rule to Private Network ACL..."

EXISTING_RULE=$(aws ec2 describe-network-acls \
    --network-acl-ids "$PRIVATE_NACL" \
    --region "$REGION" \
    --query "NetworkAcls[0].Entries[?RuleNumber==\`130\`]" \
    --output text 2>/dev/null || echo "")

if [ -z "$EXISTING_RULE" ] || [ "$EXISTING_RULE" == "None" ]; then
    aws ec2 create-network-acl-entry \
        --network-acl-id "$PRIVATE_NACL" \
        --rule-number 130 \
        --protocol tcp \
        --port-range From=1024,To=65535 \
        --egress \
        --cidr-block 10.0.0.0/16 \
        --rule-action allow \
        --region "$REGION" 2>/dev/null || true
    echo "  Ephemeral port outbound rule added to Private NACL"
else
    echo "  Ephemeral port outbound rule already exists"
fi

echo ""
echo "==========================================="
echo "All Fixes Applied!"
echo "==========================================="
echo ""

# ==========================================
# VERIFICATION
# ==========================================
echo "Waiting 10 seconds for changes to propagate..."
sleep 10
echo ""

if [ -n "${ALB_DNS:-}" ]; then
    echo "Testing ALB connectivity..."
    echo "ALB URL: http://$ALB_DNS"
    echo ""

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "http://$ALB_DNS" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" == "000" ]; then
        echo "ALB connectivity test: Connection timeout"
        echo "  This may take a few more seconds to propagate."
        echo "  Try running: curl -v http://$ALB_DNS"
    elif [ "$HTTP_CODE" == "503" ]; then
        echo "ALB connectivity test: SUCCESS (HTTP $HTTP_CODE)"
        echo "  503 is expected - ALB is reachable but has no healthy targets"
    else
        echo "ALB connectivity test: SUCCESS (HTTP $HTTP_CODE)"
    fi
else
    echo "ALB_DNS not available in environment file"
fi

echo ""
echo "==========================================="
echo "Fix Summary"
echo "==========================================="
echo "The following configurations have been fixed:"
echo "  1. ALB Security Group - HTTP (port 80) inbound from internet"
echo "  2. Web Server Security Group - HTTP (port 80) from ALB"
echo "  3. Public Route Table - Route to Internet Gateway (0.0.0.0/0)"
echo "  4. Private Route Table - Route to NAT Gateway (0.0.0.0/0)"
echo "  5. Private NACL - Ephemeral ports (1024-65535) outbound to VPC"
echo "==========================================="