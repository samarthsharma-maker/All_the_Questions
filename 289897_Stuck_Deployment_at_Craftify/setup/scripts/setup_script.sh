#!/bin/bash
set -euo pipefail

LAB_DIR="/home/user/craftify-deploy-lab"
mkdir -p "$LAB_DIR"

apt update
apt install -y zip unzip > /dev/null 2>&1
# ---------------------------------------------------------------------------
# Write setup.sh
# ---------------------------------------------------------------------------
cat > "$LAB_DIR/setup.sh" << 'SETUP_SCRIPT'
#!/bin/bash
set -euo pipefail

export AWS_PAGER=""
export AWS_DEFAULT_REGION="us-west-2"

REGION="us-west-2"
LAB_DIR="/home/user/craftify-deploy-lab"
KEY_NAME="craftify-deploy-key"
KEY_PATH="$LAB_DIR/$KEY_NAME.pem"
PIPELINE_NAME="craftify-release-pipeline"
APP_NAME="craftify-backend"
DG_NAME="craftify-deployment-group"

echo "========================================="
echo "  Craftify Deploy Lab — Setup"
echo "========================================="
echo ""

# ---------------------------------------------------------------------------
# Account & bucket names
# ---------------------------------------------------------------------------
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
SOURCE_BUCKET="craftify-source-${ACCOUNT_ID}"
ARTIFACT_BUCKET="craftify-artifacts-${ACCOUNT_ID}"

# ---------------------------------------------------------------------------
# 1. Key pair
# ---------------------------------------------------------------------------
echo "[1/10] Creating key pair..."
aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION" 2>/dev/null || true
rm -f "$KEY_PATH"
aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --region "$REGION" \
    --query "KeyMaterial" \
    --output text > "$KEY_PATH"
chmod 400 "$KEY_PATH"

# ---------------------------------------------------------------------------
# 2. S3 buckets
# ---------------------------------------------------------------------------
echo "[2/10] Creating S3 buckets..."

for BUCKET in "$SOURCE_BUCKET" "$ARTIFACT_BUCKET"; do
    aws s3api head-bucket --bucket "$BUCKET" --region "$REGION" 2>/dev/null || \
        aws s3api create-bucket \
            --bucket "$BUCKET" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
done

aws s3api put-bucket-versioning \
    --bucket "$SOURCE_BUCKET" \
    --versioning-configuration Status=Enabled

# ---------------------------------------------------------------------------
# 3. Build and upload deployment artifact
# ---------------------------------------------------------------------------
echo "[3/10] Building deployment artifact..."

TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/html" "$TMP_DIR/scripts"

cat > "$TMP_DIR/appspec.yml" << 'APPSPEC'
version: 0.0
os: linux
files:
  - source: html/index.html
    destination: /var/www/html
hooks:
  BeforeInstall:
    - location: scripts/install_httpd.sh
      timeout: 60
      runas: root
  ApplicationStart:
    - location: scripts/start_httpd.sh
      timeout: 30
      runas: root
APPSPEC

cat > "$TMP_DIR/scripts/install_httpd.sh" << 'SH'
#!/bin/bash
yum install -y httpd
SH

cat > "$TMP_DIR/scripts/start_httpd.sh" << 'SH'
#!/bin/bash
systemctl enable httpd
systemctl start httpd
SH

cat > "$TMP_DIR/html/index.html" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>Craftify Learning Platform</title></head>
<body>
  <h1>Craftify Learning Platform</h1>
  <p>Version 2.1.3</p>
</body>
</html>
HTML

chmod +x "$TMP_DIR/scripts/"*.sh

ARTIFACT_ZIP="/tmp/craftify-backend.zip"
(cd "$TMP_DIR" && zip -qr "$ARTIFACT_ZIP" .)
rm -rf "$TMP_DIR"

aws s3 cp "$ARTIFACT_ZIP" "s3://${SOURCE_BUCKET}/craftify-backend.zip"
rm -f "$ARTIFACT_ZIP"

# ---------------------------------------------------------------------------
# 4. IAM — EC2 instance role + profile
# ---------------------------------------------------------------------------
echo "[4/10] Creating IAM roles..."

EC2_TRUST='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
DEPLOY_TRUST='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"codedeploy.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
PIPELINE_TRUST='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"codepipeline.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

# EC2 role
aws iam create-role \
    --role-name craftify-ec2-role \
    --assume-role-policy-document "$EC2_TRUST" 2>/dev/null || true
aws iam attach-role-policy \
    --role-name craftify-ec2-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy 2>/dev/null || true
aws iam attach-role-policy \
    --role-name craftify-ec2-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore 2>/dev/null || true

# Instance profile
aws iam create-instance-profile \
    --instance-profile-name craftify-ec2-profile 2>/dev/null || true
aws iam add-role-to-instance-profile \
    --instance-profile-name craftify-ec2-profile \
    --role-name craftify-ec2-role 2>/dev/null || true

# CodeDeploy service role
aws iam create-role \
    --role-name craftify-codedeploy-role \
    --assume-role-policy-document "$DEPLOY_TRUST" 2>/dev/null || true
aws iam attach-role-policy \
    --role-name craftify-codedeploy-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole 2>/dev/null || true

# CodePipeline service role
aws iam create-role \
    --role-name craftify-pipeline-role \
    --assume-role-policy-document "$PIPELINE_TRUST" 2>/dev/null || true

PIPELINE_POLICY=$(cat << POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:GetBucketVersioning"
      ],
      "Resource": [
        "arn:aws:s3:::${SOURCE_BUCKET}",
        "arn:aws:s3:::${SOURCE_BUCKET}/*",
        "arn:aws:s3:::${ARTIFACT_BUCKET}",
        "arn:aws:s3:::${ARTIFACT_BUCKET}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment",
        "codedeploy:GetDeploymentConfig",
        "codedeploy:GetApplicationRevision",
        "codedeploy:RegisterApplicationRevision"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
)

aws iam put-role-policy \
    --role-name craftify-pipeline-role \
    --policy-name craftify-pipeline-inline \
    --policy-document "$PIPELINE_POLICY" 2>/dev/null || true

echo "  Waiting for IAM to propagate..."
sleep 15

# ---------------------------------------------------------------------------
# 5. Networking — default VPC, subnet, security group
# ---------------------------------------------------------------------------
echo "[5/10] Resolving network resources..."

VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region "$REGION")

SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=defaultForAz,Values=true" \
    --query "Subnets[0].SubnetId" \
    --output text \
    --region "$REGION")

SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=craftify-sg" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" \
    --output text \
    --region "$REGION" 2>/dev/null || echo "None")

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
    SG_ID=$(aws ec2 create-security-group \
        --group-name craftify-sg \
        --description "Craftify lab security group" \
        --vpc-id "$VPC_ID" \
        --region "$REGION" \
        --query "GroupId" \
        --output text)

    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 \
        --region "$REGION" 2>/dev/null || true

    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 \
        --region "$REGION" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 6. AMI lookup
# ---------------------------------------------------------------------------
echo "[6/10] Looking up Amazon Linux 2 AMI..."

AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters \
        "Name=name,Values=amzn2-ami-hvm-2.0.*-x86_64-gp2" \
        "Name=state,Values=available" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text \
    --region "$REGION")

echo "  AMI: $AMI_ID"

# ---------------------------------------------------------------------------
# 7. EC2 instance — CodeDeploy agent installed but stopped + disabled
# ---------------------------------------------------------------------------
echo "[7/10] Launching EC2 instance..."

# NOTE: agent is installed automatically by the installer, then immediately
# stopped and disabled to create the broken state the learner must fix.
USER_DATA=$(cat << 'USERDATA'
#!/bin/bash
yum update -y
yum install -y ruby wget

cd /tmp
wget -q https://aws-codedeploy-us-west-2.s3.us-west-2.amazonaws.com/latest/install
chmod +x ./install
./install auto

# Agent starts automatically after install — stop and disable it
sleep 5
systemctl stop codedeploy-agent
systemctl disable codedeploy-agent
USERDATA
)

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t3.micro \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --subnet-id "$SUBNET_ID" \
    --iam-instance-profile Name=craftify-ec2-profile \
    --user-data "$USER_DATA" \
    --associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=craftify-app-server}]" \
    --region "$REGION" \
    --query "Instances[0].InstanceId" \
    --output text)

echo "  Instance: $INSTANCE_ID — waiting for running state..."

aws ec2 wait instance-running \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION"

INSTANCE_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

echo "  Instance IP: $INSTANCE_IP"

# ---------------------------------------------------------------------------
# 8. CodeDeploy application + deployment group
# ---------------------------------------------------------------------------
echo "[8/10] Creating CodeDeploy application and deployment group..."

CODEDEPLOY_ROLE_ARN=$(aws iam get-role \
    --role-name craftify-codedeploy-role \
    --query "Role.Arn" \
    --output text)

aws deploy create-application \
    --application-name "$APP_NAME" \
    --compute-platform Server \
    --region "$REGION" 2>/dev/null || true

aws deploy create-deployment-group \
    --application-name "$APP_NAME" \
    --deployment-group-name "$DG_NAME" \
    --service-role-arn "$CODEDEPLOY_ROLE_ARN" \
    --ec2-tag-filters "Key=Name,Type=KEY_AND_VALUE,Value=craftify-app-server" \
    --deployment-config-name CodeDeployDefault.OneAtATime \
    --region "$REGION" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 9. CodePipeline
# ---------------------------------------------------------------------------
echo "[9/10] Creating CodePipeline..."

PIPELINE_ROLE_ARN=$(aws iam get-role \
    --role-name craftify-pipeline-role \
    --query "Role.Arn" \
    --output text)

PIPELINE_DEF_FILE=$(mktemp /tmp/pipeline-XXXX.json)
cat > "$PIPELINE_DEF_FILE" << PIPELINEJSON
{
  "name": "${PIPELINE_NAME}",
  "roleArn": "${PIPELINE_ROLE_ARN}",
  "artifactStore": {
    "type": "S3",
    "location": "${ARTIFACT_BUCKET}"
  },
  "stages": [
    {
      "name": "Source",
      "actions": [
        {
          "name": "S3Source",
          "actionTypeId": {
            "category": "Source",
            "owner": "AWS",
            "provider": "S3",
            "version": "1"
          },
          "configuration": {
            "S3Bucket": "${SOURCE_BUCKET}",
            "S3ObjectKey": "craftify-backend.zip",
            "PollForSourceChanges": "true"
          },
          "outputArtifacts": [{"name": "SourceArtifact"}],
          "runOrder": 1
        }
      ]
    },
    {
      "name": "Deploy",
      "actions": [
        {
          "name": "CodeDeployDeploy",
          "actionTypeId": {
            "category": "Deploy",
            "owner": "AWS",
            "provider": "CodeDeploy",
            "version": "1"
          },
          "configuration": {
            "ApplicationName": "${APP_NAME}",
            "DeploymentGroupName": "${DG_NAME}"
          },
          "inputArtifacts": [{"name": "SourceArtifact"}],
          "runOrder": 1
        }
      ]
    }
  ]
}
PIPELINEJSON

aws codepipeline create-pipeline \
    --pipeline "file://${PIPELINE_DEF_FILE}" \
    --region "$REGION" 2>/dev/null || true

rm -f "$PIPELINE_DEF_FILE"

# Trigger pipeline immediately (don't rely on poll interval timing)
aws codepipeline start-pipeline-execution \
    --name "$PIPELINE_NAME" \
    --region "$REGION" > /dev/null

# ---------------------------------------------------------------------------
# 10. Save lab config
# ---------------------------------------------------------------------------
echo "[10/10] Saving lab config..."

cat > "$LAB_DIR/lab-config.txt" << CONFIG
REGION=${REGION}
INSTANCE_ID=${INSTANCE_ID}
INSTANCE_IP=${INSTANCE_IP}
KEY_PATH=${KEY_PATH}
KEY_NAME=${KEY_NAME}
PIPELINE_NAME=${PIPELINE_NAME}
APP_NAME=${APP_NAME}
DG_NAME=${DG_NAME}
SOURCE_BUCKET=${SOURCE_BUCKET}
ARTIFACT_BUCKET=${ARTIFACT_BUCKET}
CONFIG

chown -R user:user "$LAB_DIR"

echo ""
echo "========================================="
echo "  Lab Environment Ready"
echo "========================================="
echo ""
echo "  Instance IP : $INSTANCE_IP"
echo "  Key path    : $KEY_PATH"
echo ""
echo "  Pipeline    : $PIPELINE_NAME  (us-west-2)"
echo "  Deploy stage is now stuck — Waiting for agent."
echo ""
echo "  Wait 3-4 minutes before SSHing in."
echo "  SSH command:"
echo "    ssh -i $KEY_PATH ec2-user@$INSTANCE_IP"
echo ""
SETUP_SCRIPT

# ---------------------------------------------------------------------------
# Permissions
# ---------------------------------------------------------------------------
chmod +x "$LAB_DIR/setup.sh"
chown -R user:user "$LAB_DIR"

echo "Pre-req complete: setup.sh written to $LAB_DIR/setup.sh"