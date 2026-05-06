# Deploying an EC2 Instance with Additional Storage and Network Security

## Overview

You are a systems administrator tasked with deploying a new EC2 instance for a file server application. The server needs:
- Additional storage beyond the root volume
- Secure network access (SSH only from your IP)
- Proper filesystem configuration
- Data persistence

## Setup Instructions

**Run the setup script first:**
```bash
./setup_ec2_ebs_lab.sh
```

**Wait for completion** (~30 seconds).

The setup script creates:
- VPC and subnet information
- Amazon Linux 2023 AMI reference
- SSH key pair for instance access
- IAM role for Systems Manager access

All resource details will be saved to `/tmp/ec2_ebs_lab_env.txt`.

---

## What Has Been Created For You

| Resource | Name/Details | Purpose |
|----------|-------------|---------|
| **VPC** | Default VPC | Network environment |
| **Subnet** | Public subnet in default VPC | Instance placement |
| **AMI** | Amazon Linux 2023 (latest) | Instance operating system |
| **SSH Key Pair** | `ec2-lab-key-{ACCOUNT_ID}` | Secure instance access |
| **IAM Role** | `EC2-SSM-Role` | Systems Manager access |
| **Instance Profile** | `EC2-SSM-InstanceProfile` | Attach role to instance |

---

## What You Need to Create

You must create the following resources with **exact names**:

### 1. Security Group
- **Name:** `file-server-sg`
- **Description:** `Security group for file server`
- **VPC:** Use the default VPC (provided in env file)
- **Inbound Rules:**
  - SSH (port 22) from your IP only
  - Custom rule: Allow all traffic from within the same security group (for future instances)
- **Outbound Rules:** 
  - Allow all traffic

### 2. EC2 Instance
- **Name Tag:** `file-server-01`
- **Instance Type:** `t2.micro`
- **AMI:** Use AMI_ID from env file
- **Key Pair:** Use KEY_NAME from env file
- **Security Group:** `file-server-sg` (the one you created)
- **IAM Instance Profile:** Use INSTANCE_PROFILE_ARN from env file
- **Subnet:** Use SUBNET_ID from env file
- **Public IP:** Enable auto-assign public IP
- **Additional Tags:**
  - `Environment=Development`
  - `Application=FileServer`

### 3. EBS Volume
- **Name Tag:** `file-server-data`
- **Size:** `10 GB`
- **Volume Type:** `gp3`
- **Availability Zone:** Same AZ as EC2 instance (use AZ from env file)
- **Encrypted:** Yes
- **Additional Tags:**
  - `Purpose=DataStorage`

### 4. Volume Attachment
- **Attach the EBS volume to the EC2 instance**
- **Device Name:** `/dev/sdf`

### 5. Filesystem Configuration (SSH into instance)
- Format the volume as `ext4`
- Create mount point: `/data`
- Mount the volume
- Create a test file to verify
- Configure auto-mount on reboot (optional)

---

## Detailed Requirements

### Security Group Requirements

Your security group must:
- Be named exactly `file-server-sg`
- Be in the default VPC
- Have SSH inbound rule restricted to your IP (get from `curl ifconfig.me`)
- Have self-referencing rule (source = same security group)
- Allow all outbound traffic

### EC2 Instance Requirements

Your instance must:
- Use `t2.micro` instance type
- Be named `file-server-01` via Name tag
- Have IAM instance profile attached for SSM
- Be in a public subnet with public IP
- Use the provided SSH key pair
- Have security group `file-server-sg` attached

### EBS Volume Requirements

Your volume must:
- Be exactly 10 GB
- Be type `gp3` (general purpose SSD)
- Be encrypted (default KMS key is fine)
- Be in the same AZ as the instance
- Be tagged with name `file-server-data`

### Volume Attachment Requirements

- Volume must be attached to instance
- Device name must be `/dev/sdf`
- Attachment state must be `attached`

### Filesystem Requirements

- Volume formatted as ext4
- Mounted at `/data`
- Test file created in `/data` to verify persistence
- Writable by ec2-user

---

## Step-by-Step Instructions

### Step 1: Load Environment Variables
```bash
# Load environment
source /tmp/ec2_ebs_lab_env.txt

# Verify variables
echo "Region: $REGION"
echo "VPC: $VPC_ID"
echo "Subnet: $SUBNET_ID"
echo "AMI: $AMI_ID"
echo "Key: $KEY_NAME"
```

### Step 2: Get Your Public IP
```bash
# Get your current public IP (for SSH access)
MY_IP=$(curl -s ifconfig.me)
echo "Your IP: $MY_IP"
```

### Step 3: Create Security Group
```bash
# Create security group
SG_ID=$(aws ec2 create-security-group \
    --group-name file-server-sg \
    --description "Security group for file server" \
    --vpc-id $VPC_ID \
    --region $REGION \
    --query 'GroupId' \
    --output text)

echo "Security Group created: $SG_ID"

# Add SSH rule from your IP
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr ${MY_IP}/32 \
    --region $REGION

# Add self-referencing rule (all traffic from same SG)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol -1 \
    --source-group $SG_ID \
    --region $REGION

echo "Security group rules configured"
```

### Step 4: Launch EC2 Instance
```bash
# Launch instance
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type t2.micro \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_ID \
    --iam-instance-profile Arn=$INSTANCE_PROFILE_ARN \
    --associate-public-ip-address \
    --tag-specifications \
        'ResourceType=instance,Tags=[{Key=Name,Value=file-server-01},{Key=Environment,Value=Development},{Key=Application,Value=FileServer}]' \
    --region $REGION \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance launching: $INSTANCE_ID"

# Wait for instance to be running
echo "Waiting for instance to be running..."
aws ec2 wait instance-running \
    --instance-ids $INSTANCE_ID \
    --region $REGION

echo "Instance is running!"

# Get instance public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "Instance Public IP: $PUBLIC_IP"
```

### Step 5: Create EBS Volume
```bash
# Create EBS volume in same AZ as instance
VOLUME_ID=$(aws ec2 create-volume \
    --volume-type gp3 \
    --size 10 \
    --availability-zone $AZ \
    --encrypted \
    --tag-specifications \
        'ResourceType=volume,Tags=[{Key=Name,Value=file-server-data},{Key=Purpose,Value=DataStorage}]' \
    --region $REGION \
    --query 'VolumeId' \
    --output text)

echo "Volume created: $VOLUME_ID"

# Wait for volume to be available
echo "Waiting for volume to be available..."
aws ec2 wait volume-available \
    --volume-ids $VOLUME_ID \
    --region $REGION

echo "Volume is available!"
```

### Step 6: Attach Volume to Instance
```bash
# Attach volume
aws ec2 attach-volume \
    --volume-id $VOLUME_ID \
    --instance-id $INSTANCE_ID \
    --device /dev/sdf \
    --region $REGION

echo "Volume attached to instance"

# Wait a moment for attachment
sleep 10
```

### Step 7: Format and Mount Volume
```bash
# SSH into instance
echo "Connecting to instance via SSH..."
echo "If this fails, wait 30 seconds and try again (instance still initializing)"

# SSH command (you'll need to run these commands on the instance)
ssh -i $KEY_PATH -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP
```

**Once connected to the instance, run these commands:**
```bash
# List block devices to verify volume is attached
lsblk

# Format the volume (WARNING: This erases all data on the volume)
sudo mkfs -t ext4 /dev/xvdf

# Create mount point
sudo mkdir -p /data

# Mount the volume
sudo mount /dev/xvdf /data

# Verify mount
df -h /data

# Change ownership to ec2-user
sudo chown ec2-user:ec2-user /data

# Create test file
echo "This is test data on EBS volume" > /data/test.txt

# Verify test file
cat /data/test.txt

# Optional: Configure auto-mount on reboot
echo '/dev/xvdf /data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab

# Verify fstab
sudo cat /etc/fstab

# Exit SSH
exit
```

### Step 8: Verify from AWS CLI
```bash
# Check volume attachment status
aws ec2 describe-volumes \
    --volume-ids $VOLUME_ID \
    --region $REGION \
    --query 'Volumes[0].Attachments[0].[State,Device]' \
    --output table

# Should show "attached" and "/dev/sdf"
```

---

## Success Criteria

Your deployment is successful when:

- Security group `file-server-sg` exists with correct rules
- SSH rule allows access from your IP only
- Self-referencing rule allows internal communication
- EC2 instance `file-server-01` is running
- Instance type is `t2.micro`
- Instance has all required tags
- Instance has public IP assigned
- Instance has IAM instance profile attached
- EBS volume `file-server-data` exists
- Volume is 10 GB, type gp3, encrypted
- Volume is in same AZ as instance
- Volume is attached to instance as `/dev/sdf`
- Volume is formatted as ext4
- Volume is mounted at `/data`
- Test file exists in `/data` directory
- Can SSH into instance using provided key

---

## Verification Commands
```bash
# Load environment
source /tmp/ec2_ebs_lab_env.txt

# Check security group
aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=file-server-sg" \
    --region $REGION

# Check instance
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=file-server-01" \
    --region $REGION

# Check volume
aws ec2 describe-volumes \
    --filters "Name=tag:Name,Values=file-server-data" \
    --region $REGION

# Check volume attachment
aws ec2 describe-volumes \
    --filters "Name=attachment.instance-id,Values=<INSTANCE_ID>" \
    --region $REGION

# SSH into instance
ssh -i $KEY_PATH ec2-user@<PUBLIC_IP>

# Once in instance, verify mount
df -h /data
ls -la /data
cat /data/test.txt
```

---

## Troubleshooting

### Cannot SSH into instance

Check:
- Security group has SSH rule with your current IP
- Instance has public IP
- Instance is in running state
- Key pair permissions: `chmod 400 /tmp/ec2-lab-key-*.pem`
- Try: `ssh -i $KEY_PATH -v ec2-user@$PUBLIC_IP` for verbose output

### Volume not visible in instance

Check:
- Volume is in same AZ as instance
- Volume state is `in-use`
- Run `lsblk` on instance to see all block devices
- Device might appear as `/dev/xvdf` instead of `/dev/sdf`

### Cannot format volume

Check:
- You have sudo access
- Volume is not already formatted (use `sudo file -s /dev/xvdf`)
- Volume is the correct device (verify with `lsblk`)

### Mount fails

Check:
- Volume is formatted (`sudo file -s /dev/xvdf` should show ext4)
- Mount point directory exists (`sudo mkdir -p /data`)
- No other filesystem already mounted there (`df -h`)

---

## Resource Names Reference

**Use these exact names:**

| Resource Type | Exact Name to Use |
|--------------|-------------------|
| Security Group | `file-server-sg` |
| EC2 Instance (Name tag) | `file-server-01` |
| EBS Volume (Name tag) | `file-server-data` |
| Mount Point | `/data` |
| Device Name | `/dev/sdf` |

**Use these from environment file:**

| Resource | Variable Name |
|----------|--------------|
| VPC ID | `$VPC_ID` |
| Subnet ID | `$SUBNET_ID` |
| Availability Zone | `$AZ` |
| AMI ID | `$AMI_ID` |
| Key Name | `$KEY_NAME` |
| Key Path | `$KEY_PATH` |
| Instance Profile ARN | `$INSTANCE_PROFILE_ARN` |
| Region | `$REGION` |

---

## Key Concepts

### Security Groups
- Act as virtual firewalls for instances
- Stateful (return traffic automatically allowed)
- Can reference other security groups
- Best practice: Restrict SSH to specific IPs

### EBS Volumes
- Block-level storage for EC2
- Persist independently from instance
- Must be in same AZ as instance
- Can be encrypted at rest
- Types: gp3 (general purpose), io2 (high performance), st1 (throughput optimized)

### Volume Attachment
- Attaches as block device to instance
- Must be formatted before use
- Device names: `/dev/sdf` through `/dev/sdp`
- Linux may rename to `/dev/xvdf` (NVMe instances)

### Filesystem Operations
- `mkfs`: Format volume with filesystem
- `mount`: Attach filesystem to directory tree
- `fstab`: Configure automatic mounting at boot
- `df`: Show disk space usage

---

## Time Estimate
8-12 minutes

---

## Additional Resources

- [Amazon EBS Volumes](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volumes.html)
- [Security Groups](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-security-groups.html)
- [Making an EBS Volume Available](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-using-volumes.html)
- [Device Naming on Linux](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html)