#!/bin/bash

REGION="us-west-2"
ASG_NAME="datastream-worker-asg"
LOG_GROUP="/aws/datastream/processor"
export AWS_PAGER=""

echo "Fixing FinOps issues..."

#################################################
# Fix ASG
#################################################

aws autoscaling update-auto-scaling-group \
--auto-scaling-group-name $ASG_NAME \
--min-size 0 \
--desired-capacity 0 \
--max-size 5 \
--region $REGION

#################################################
# Fix S3 lifecycle
#################################################

BUCKET=$(aws s3api list-buckets \
--query 'Buckets[?contains(Name,`datastream-temp-results`)].Name' \
--output text)

cat <<EOF > lifecycle.json
{
 "Rules":[
  {
   "ID":"delete-old-files",
   "Status":"Enabled",
   "Filter":{"Prefix":""},
   "Expiration":{"Days":7}
  }
 ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
--bucket $BUCKET \
--lifecycle-configuration file://lifecycle.json

#################################################
# Fix log retention
#################################################

aws logs put-retention-policy \
--log-group-name $LOG_GROUP \
--retention-in-days 14 \
--region $REGION

#################################################
# Stop debug instance
#################################################

INSTANCE=$(aws ec2 describe-instances \
--filters "Name=tag:Name,Values=datastream-dev-debug" \
--query 'Reservations[].Instances[].InstanceId' \
--output text \
--region $REGION)

aws ec2 stop-instances \
--instance-ids $INSTANCE \
--region $REGION >/dev/null

echo "All FinOps fixes applied."