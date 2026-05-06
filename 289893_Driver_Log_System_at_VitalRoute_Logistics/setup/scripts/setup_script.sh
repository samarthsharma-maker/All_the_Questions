#!/bin/bash
set -euo pipefail

LAB_DIR="/home/user/vitalroute-efs-lab"
mkdir -p "$LAB_DIR"

cat > "$LAB_DIR/setup.sh" << 'SETUPEOF'
#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
LAB_DIR="/home/user/vitalroute-efs-lab"
KEY_NAME="vitalroute-efs-key"
KEY_PATH="$LAB_DIR/${KEY_NAME}.pem"

mkdir -p "$LAB_DIR"

apt-get update -y > /dev/null 2>&1 && apt-get install -y netcat-openbsd > /dev/null 2>&1 \
    || yum install -y nc > /dev/null 2>&1

VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text --region "$REGION")

VPC_CIDR=$(aws ec2 describe-vpcs \
    --vpc-ids "$VPC_ID" \
    --query "Vpcs[0].CidrBlock" \
    --output text --region "$REGION")

SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=defaultForAz,Values=true" \
    --query "Subnets[?AvailabilityZone!='us-west-2d'] | [0].SubnetId" \
    --output text --region "$REGION")

# Create key pair — single .pem used for both instances
aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --query "KeyMaterial" \
    --output text \
    --region "$REGION" > "$KEY_PATH"
chmod 400 "$KEY_PATH"

# EC2 security group
EC2_SG_ID=$(aws ec2 create-security-group \
    --group-name "vitalroute-ec2-sg" \
    --description "VitalRoute EC2 security group" \
    --vpc-id "$VPC_ID" \
    --query "GroupId" \
    --output text --region "$REGION")

aws ec2 authorize-security-group-ingress \
    --group-id "$EC2_SG_ID" \
    --protocol tcp --port 22 \
    --cidr "0.0.0.0/0" \
    --region "$REGION"

# EFS security group — intentional bug: VPC CIDR instead of EC2 SG
EFS_SG_ID=$(aws ec2 create-security-group \
    --group-name "vitalroute-efs-sg" \
    --description "VitalRoute EFS security group" \
    --vpc-id "$VPC_ID" \
    --query "GroupId" \
    --output text --region "$REGION")

aws ec2 authorize-security-group-ingress \
    --group-id "$EFS_SG_ID" \
    --protocol tcp --port 2049 \
    --cidr "$VPC_CIDR" \
    --region "$REGION"

# EFS filesystem
EFS_ID=$(aws efs create-file-system \
    --performance-mode generalPurpose \
    --region "$REGION" \
    --query "FileSystemId" \
    --output text)

echo "Waiting for EFS..."
while true; do
    STATE=$(aws efs describe-file-systems \
        --file-system-id "$EFS_ID" \
        --region "$REGION" \
        --query "FileSystems[0].LifeCycleState" \
        --output text)
    if [ "$STATE" == "available" ]; then break; fi
    sleep 5
done

aws efs create-mount-target \
    --file-system-id "$EFS_ID" \
    --subnet-id "$SUBNET_ID" \
    --security-groups "$EFS_SG_ID" \
    --region "$REGION"

echo "Waiting for mount target..."
while true; do
    MT_STATE=$(aws efs describe-mount-targets \
        --file-system-id "$EFS_ID" \
        --region "$REGION" \
        --query "MountTargets[0].LifeCycleState" \
        --output text)
    if [ "$MT_STATE" == "available" ]; then break; fi
    sleep 5
done

echo "Waiting for DNS propagation..."
sleep 30

EFS_DNS="${EFS_ID}.efs.${REGION}.amazonaws.com"

AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text --region "$REGION")

# User data for server-1 — mounts EFS correctly
USER_DATA_1=$(cat << EOF
#!/bin/bash
yum install -y amazon-efs-utils
mkdir -p /mnt/efs
echo "${EFS_DNS}:/ /mnt/efs efs defaults,_netdev 0 0" >> /etc/fstab
mount -a
EOF
)

# User data for server-2 — installs utils only, NO fstab entry (intentional bug)
USER_DATA_2=$(cat << EOF
#!/bin/bash
yum install -y amazon-efs-utils
mkdir -p /mnt/efs
EOF
)

# Both instances use the same key pair
INSTANCE_1=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t2.micro \
    --key-name "$KEY_NAME" \
    --security-group-ids "$EC2_SG_ID" \
    --subnet-id "$SUBNET_ID" \
    --associate-public-ip-address \
    --user-data "$USER_DATA_1" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=vitalroute-server-1}]" \
    --query "Instances[0].InstanceId" \
    --output text --region "$REGION")

INSTANCE_2=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t2.micro \
    --key-name "$KEY_NAME" \
    --security-group-ids "$EC2_SG_ID" \
    --subnet-id "$SUBNET_ID" \
    --associate-public-ip-address \
    --user-data "$USER_DATA_2" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=vitalroute-server-2}]" \
    --query "Instances[0].InstanceId" \
    --output text --region "$REGION")

aws ec2 wait instance-running \
    --instance-ids "$INSTANCE_1" "$INSTANCE_2" \
    --region "$REGION"

IP_1=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_1" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text --region "$REGION")

IP_2=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_2" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text --region "$REGION")

cat > "$LAB_DIR/lab-config.txt" << EOF
EFS_ID=$EFS_ID
EFS_DNS=$EFS_DNS
EFS_SG_ID=$EFS_SG_ID
EC2_SG_ID=$EC2_SG_ID
INSTANCE_1=$INSTANCE_1
INSTANCE_2=$INSTANCE_2
IP_1=$IP_1
IP_2=$IP_2
KEY_PATH=$KEY_PATH
VPC_CIDR=$VPC_CIDR
EOF

chown -R user:user "$LAB_DIR"

echo ""
echo "========================================="
echo "  Lab Environment Ready"
echo "========================================="
echo ""
echo "EFS DNS     : $EFS_DNS"
echo "Server 1 IP : $IP_1"
echo "Server 2 IP : $IP_2"
echo "SSH key     : $KEY_PATH"
echo ""
echo "SSH command : ssh -i $KEY_PATH ec2-user@<SERVER-IP>"
echo ""
echo "Wait 2-3 minutes before SSHing in."
echo ""
SETUPEOF

chmod +x "$LAB_DIR/setup.sh"
chown -R user:user "$LAB_DIR"

echo ""
echo "Run the following to provision the lab:"
echo ""
echo "  sudo bash /home/user/vitalroute-efs-lab/setup.sh"
echo ""
echo "Sudo password: user@123!"
echo ""