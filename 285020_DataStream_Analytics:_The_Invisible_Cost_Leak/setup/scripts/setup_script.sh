#!/bin/bash

set -e

export AWS_PAGER=""
REGION="us-west-2"
BASE_DIR="/home/user/datastream-finops-lab"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ASG_NAME="datastream-worker-asg"
LAUNCH_TEMPLATE="datastream-worker-lt"
BUCKET="datastream-temp-results-${ACCOUNT_ID}"
LOG_GROUP="/aws/datastream/processor"

mkdir -p $BASE_DIR

echo "[setup] Starting FinOps lab setup..."

#################################################
# Find latest Amazon Linux AMI
#################################################

AMI=$(aws ec2 describe-images \
--owners amazon \
--filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
--query 'sort_by(Images,&CreationDate)[-1].ImageId' \
--output text \
--region $REGION)

#################################################
# Launch Template
#################################################

aws ec2 create-launch-template \
--launch-template-name $LAUNCH_TEMPLATE \
--launch-template-data "{
\"ImageId\":\"$AMI\",
\"InstanceType\":\"t3.micro\"
}" \
--region $REGION || true

#################################################
# Get subnets
#################################################

SUBNETS=$(aws ec2 describe-subnets \
--query 'Subnets[0:2].SubnetId' \
--output text \
--region $REGION | tr '\t' ',')

#################################################
# Create ASG (broken config)
#################################################

aws autoscaling create-auto-scaling-group \
--auto-scaling-group-name $ASG_NAME \
--launch-template LaunchTemplateName=$LAUNCH_TEMPLATE,Version=\$Latest \
--min-size 4 \
--desired-capacity 4 \
--max-size 10 \
--vpc-zone-identifier $SUBNETS \
--region $REGION || true

#################################################
# Create S3 bucket
#################################################

aws s3api create-bucket \
--bucket $BUCKET \
--region $REGION \
--create-bucket-configuration LocationConstraint=$REGION

#################################################
# Upload dummy objects
#################################################

touch $BASE_DIR/tempfile

for i in {1..5}
do
aws s3 cp $BASE_DIR/tempfile s3://$BUCKET/file$i.txt
done

#################################################
# Create log group
#################################################

aws logs create-log-group \
--log-group-name $LOG_GROUP \
--region $REGION || true

#################################################
# Launch debug EC2 instance
#################################################

aws ec2 run-instances \
--image-id $AMI \
--instance-type t3.micro \
--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=datastream-dev-debug}]' \
--region $REGION >/dev/null

#################################################

cat <<EOF > $BASE_DIR/info.txt

FinOps Lab Environment Ready

ASG: $ASG_NAME
Bucket: $BUCKET
Log Group: $LOG_GROUP
Instance Name: datastream-dev-debug

EOF

echo "[setup] Lab environment created"