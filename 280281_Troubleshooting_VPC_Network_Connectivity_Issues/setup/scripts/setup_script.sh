#!/bin/bash

set -euo pipefail

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/network_setup.sh"

# Ensure target directory exists
mkdir -p "$TARGET_DIR"

# Create the script
cat > "$TARGET_FILE" <<'EOF'
#!/bin/bash

set -euo pipefail

# ==========================================
# SETUP SCRIPT: VPC NETWORKING ENVIRONMENT
# ==========================================

REGION="${AWS_REGION:-us-west-2}"
VPC_CIDR="10.0.0.0/16"
echo "Setting up VPC networking environment in ${REGION}" >&2

# Create VPC
echo "Creating VPC..." >&2
#!/bin/bash

set -euo pipefail

# ==========================================
# SETUP SCRIPT: VPC NETWORKING ENVIRONMENT
# ==========================================

REGION="${AWS_REGION:-us-west-2}"
VPC_CIDR="10.0.0.0/16"
echo "Setting up VPC networking environment in ${REGION}" >&2

# Create VPC
echo "Creating VPC..." >&2
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block "$VPC_CIDR" \
    --region "$REGION" \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=NetworkTroubleshootingVPC}]' \
    --query 'Vpc.VpcId' \
    --output text)

aws ec2 modify-vpc-attribute \
    --vpc-id "$VPC_ID" \
    --enable-dns-hostnames \
    --region "$REGION"

# Create Internet Gateway
echo "Creating Internet Gateway..." >&2
IGW_ID=$(aws ec2 create-internet-gateway \
    --region "$REGION" \
    --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=NetworkTroubleshootingIGW}]' \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

aws ec2 attach-internet-gateway \
    --vpc-id "$VPC_ID" \
    --internet-gateway-id "$IGW_ID" \
    --region "$REGION"

# Create Subnets
echo "Creating subnets..." >&2
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "10.0.1.0/24" \
    --availability-zone "${REGION}a" \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=PublicSubnet1},{Key=Type,Value=Public}]' \
    --query 'Subnet.SubnetId' \
    --output text)

PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "10.0.2.0/24" \
    --availability-zone "${REGION}b" \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=PublicSubnet2},{Key=Type,Value=Public}]' \
    --query 'Subnet.SubnetId' \
    --output text)

PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "10.0.10.0/24" \
    --availability-zone "${REGION}a" \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=PrivateSubnet1},{Key=Type,Value=Private}]' \
    --query 'Subnet.SubnetId' \
    --output text)

PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "10.0.11.0/24" \
    --availability-zone "${REGION}b" \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=PrivateSubnet2},{Key=Type,Value=Private}]' \
    --query 'Subnet.SubnetId' \
    --output text)

# Create NAT Gateway
echo "Creating NAT Gateway..." >&2
EIP_ALLOC=$(aws ec2 allocate-address \
    --domain vpc \
    --region "$REGION" \
    --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=NAT-EIP}]' \
    --query 'AllocationId' \
    --output text)

NAT_GW_ID=$(aws ec2 create-nat-gateway \
    --subnet-id "$PUBLIC_SUBNET_1" \
    --allocation-id "$EIP_ALLOC" \
    --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=NetworkTroubleshootingNAT}]' \
    --query 'NatGateway.NatGatewayId' \
    --output text)

echo "Waiting for NAT Gateway to be available..." >&2
aws ec2 wait nat-gateway-available \
    --nat-gateway-ids "$NAT_GW_ID" \
    --region "$REGION"

# Create Route Tables
echo "Creating route tables..." >&2
PUBLIC_RT=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=PublicRouteTable}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

PRIVATE_RT=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=PrivateRouteTable}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Associate route tables
aws ec2 associate-route-table \
    --subnet-id "$PUBLIC_SUBNET_1" \
    --route-table-id "$PUBLIC_RT" \
    --region "$REGION" > /dev/null

aws ec2 associate-route-table \
    --subnet-id "$PUBLIC_SUBNET_2" \
    --route-table-id "$PUBLIC_RT" \
    --region "$REGION" > /dev/null

aws ec2 associate-route-table \
    --subnet-id "$PRIVATE_SUBNET_1" \
    --route-table-id "$PRIVATE_RT" \
    --region "$REGION" > /dev/null

aws ec2 associate-route-table \
    --subnet-id "$PRIVATE_SUBNET_2" \
    --route-table-id "$PRIVATE_RT" \
    --region "$REGION" > /dev/null

# Create Security Groups
echo "Creating security groups..." >&2

ALB_SG=$(aws ec2 create-security-group \
    --group-name "ALB-SG" \
    --description "ALB Security Group" \
    --vpc-id "$VPC_ID" \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ALB-SecurityGroup}]' \
    --query 'GroupId' \
    --output text)

aws ec2 authorize-security-group-ingress \
    --group-id "$ALB_SG" \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region "$REGION" 2>/dev/null || true

WEB_SG=$(aws ec2 create-security-group \
    --group-name "WebServer-SG" \
    --description "Web Server Security Group" \
    --vpc-id "$VPC_ID" \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=WebServer-SecurityGroup}]' \
    --query 'GroupId' \
    --output text)

aws ec2 authorize-security-group-ingress \
    --group-id "$WEB_SG" \
    --protocol tcp \
    --port 22 \
    --cidr 10.0.0.0/16 \
    --region "$REGION" 2>/dev/null || true

# Create Network ACL
echo "Creating Network ACLs..." >&2
PRIVATE_NACL=$(aws ec2 create-network-acl \
    --vpc-id "$VPC_ID" \
    --tag-specifications 'ResourceType=network-acl,Tags=[{Key=Name,Value=PrivateNACL}]' \
    --query 'NetworkAcl.NetworkAclId' \
    --output text)

# Allow HTTP inbound from ALB subnets
aws ec2 create-network-acl-entry \
    --network-acl-id "$PRIVATE_NACL" \
    --rule-number 100 \
    --protocol tcp \
    --port-range From=80,To=80 \
    --ingress \
    --cidr-block 10.0.0.0/16 \
    --rule-action allow \
    --region "$REGION"

# Allow HTTP outbound
aws ec2 create-network-acl-entry \
    --network-acl-id "$PRIVATE_NACL" \
    --rule-number 100 \
    --protocol tcp \
    --port-range From=80,To=80 \
    --egress \
    --cidr-block 0.0.0.0/0 \
    --rule-action allow \
    --region "$REGION"

# Allow HTTPS outbound
aws ec2 create-network-acl-entry \
    --network-acl-id "$PRIVATE_NACL" \
    --rule-number 110 \
    --protocol tcp \
    --port-range From=443,To=443 \
    --egress \
    --cidr-block 0.0.0.0/0 \
    --rule-action allow \
    --region "$REGION"

# Allow ephemeral inbound from internet for responses
aws ec2 create-network-acl-entry \
    --network-acl-id "$PRIVATE_NACL" \
    --rule-number 120 \
    --protocol tcp \
    --port-range From=1024,To=65535 \
    --ingress \
    --cidr-block 0.0.0.0/0 \
    --rule-action allow \
    --region "$REGION"

# Associate NACL with private subnets
ASSOC_1=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$PRIVATE_SUBNET_1" \
    --query 'NetworkAcls[0].Associations[?SubnetId==`'$PRIVATE_SUBNET_1'`].NetworkAclAssociationId' \
    --output text)

ASSOC_2=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$PRIVATE_SUBNET_2" \
    --query 'NetworkAcls[0].Associations[?SubnetId==`'$PRIVATE_SUBNET_2'`].NetworkAclAssociationId' \
    --output text)

aws ec2 replace-network-acl-association \
    --association-id "$ASSOC_1" \
    --network-acl-id "$PRIVATE_NACL" \
    --region "$REGION" > /dev/null

aws ec2 replace-network-acl-association \
    --association-id "$ASSOC_2" \
    --network-acl-id "$PRIVATE_NACL" \
    --region "$REGION" > /dev/null

# Create Target Group
echo "Creating Application Load Balancer..." >&2
TG_ARN=$(aws elbv2 create-target-group \
    --name web-servers-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id "$VPC_ID" \
    --health-check-enabled \
    --health-check-path "/" \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \
    --region "$REGION" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

# Create ALB
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name network-troubleshoot-alb \
    --subnets "$PUBLIC_SUBNET_1" "$PUBLIC_SUBNET_2" \
    --security-groups "$ALB_SG" \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --region "$REGION" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

echo "Waiting for ALB to be ready..." >&2
aws elbv2 wait load-balancer-available \
    --load-balancer-arns "$ALB_ARN" \
    --region "$REGION"

ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query 'LoadBalancers[0].DNSName' \
    --output text \
    --region "$REGION")

ALB_NAME=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query 'LoadBalancers[0].LoadBalancerName' \
    --output text \
    --region "$REGION")

# Create listener
LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn="$TG_ARN" \
    --region "$REGION" \
    --query 'Listeners[0].ListenerArn' \
    --output text)
touch /tmp/network_env.txt
echo "VPC_ID=$VPC_ID" >> /tmp/network_env.txt
echo "IGW_ID=$IGW_ID" >> /tmp/network_env.txt
echo "NAT_GW_ID=$NAT_GW_ID" >> /tmp/network_env.txt
echo "PUBLIC_SUBNET_1=$PUBLIC_SUBNET_1" >> /tmp/network_env.txt
echo "PUBLIC_SUBNET_2=$PUBLIC_SUBNET_2" >> /tmp/network_env.txt
echo "PRIVATE_SUBNET_1=$PRIVATE_SUBNET_1" >> /tmp/network_env.txt
echo "PRIVATE_SUBNET_2=$PRIVATE_SUBNET_2" >> /tmp/network_env.txt
echo "PUBLIC_RT=$PUBLIC_RT" >> /tmp/network_env.txt
echo "PRIVATE_RT=$PRIVATE_RT" >> /tmp/network_env.txt
echo "ALB_SG=$ALB_SG" >> /tmp/network_env.txt
echo "WEB_SG=$WEB_SG" >> /tmp/network_env.txt
echo "PRIVATE_NACL=$PRIVATE_NACL" >> /tmp/network_env.txt
echo "ALB_ARN=$ALB_ARN" >> /tmp/network_env.txt
echo "ALB_NAME=$ALB_NAME" >> /tmp/network_env.txt
echo "ALB_DNS=$ALB_DNS" >> /tmp/network_env.txt
echo "TG_ARN=$TG_ARN" >> /tmp/network_env.txt
echo "LISTENER_ARN=$LISTENER_ARN" >> /tmp/network_env.txt
echo "REGION=$REGION" >> /tmp/network_env.txt

echo "" >&2
echo "========================================" >&2
echo "Setup Complete!" >&2
echo "========================================" >&2
echo "" >&2
echo "Environment details saved to: /tmp/network_env.txt" >&2
echo "" >&2
echo "To view your environment details, run:" >&2
echo "  cat /tmp/network_env.txt" >&2
echo "" >&2
echo "ALB DNS: http://${ALB_DNS:-NOT_AVAILABLE_YET}" >&2
echo "" >&2
echo "========================================" >&2
EOF

# Set permissions to 771
sudo chmod 771 "$TARGET_FILE"
chown user:user "$TARGET_FILE"
echo "Script created at $TARGET_FILE with permissions 771"