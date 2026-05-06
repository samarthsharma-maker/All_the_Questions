#!/bin/bash
# setup-cloudwatch-lab.sh
# Safe version of the RetailPulse CloudWatch lab setup

set -uo pipefail

HOME_DIR="/home/user"
BASE_DIR="/home/user/retailpulse-lab"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"

EC2_ROLE="retailpulse-ec2-role"
POLICY_NAME="retailpulse-cloudwatch-policy"
ASG_NAME="retailpulse-app-asg"
LAUNCH_TEMPLATE_NAME="retailpulse-lt"

SNS_TOPIC_NAME="retailpulse-alerts"
SNS_TOPIC_ARN="arn:aws:sns:${REGION}:${ACCOUNT_ID}:${SNS_TOPIC_NAME}"

AGENT_CONFIG="/opt/aws/amazon-cloudwatch-agent/bin/config.json"

export AWS_PAGER=""

mkdir -p "${BASE_DIR}"

log() {
  echo "[setup] $*"
}

###########################################################
# IAM ROLE
###########################################################
create_iam_role() {

  log "Ensuring IAM role ${EC2_ROLE} exists..."

  if aws iam get-role --role-name "${EC2_ROLE}" >/dev/null 2>&1; then
      log "  ${EC2_ROLE} already exists"
      return
  fi

  trust_policy='{
    "Version":"2012-10-17",
    "Statement":[
      {
        "Effect":"Allow",
        "Principal":{"Service":"ec2.amazonaws.com"},
        "Action":"sts:AssumeRole"
      }
    ]
  }'

  aws iam create-role \
    --role-name "${EC2_ROLE}" \
    --assume-role-policy-document "${trust_policy}"

  log "  IAM role created"
}

###########################################################
# IAM POLICY (BROKEN)
###########################################################
create_iam_policy() {

log "Attaching broken inline policy..."

cat > "${BASE_DIR}/cloudwatch-policy.json" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchAgentAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVolumes",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "${EC2_ROLE}" \
  --policy-name "${POLICY_NAME}" \
  --policy-document file://"${BASE_DIR}/cloudwatch-policy.json"

log "  Broken policy attached"
}

###########################################################
# SNS TOPIC
###########################################################
create_sns_topic() {

log "Ensuring SNS topic exists..."

aws sns create-topic \
  --name "${SNS_TOPIC_NAME}" \
  --region "${REGION}" >/dev/null 2>&1

log "  SNS topic ready"
}

###########################################################
# CLOUDWATCH AGENT CONFIG (BROKEN)
###########################################################
create_agent_config() {

log "Writing broken CloudWatch agent config..."

cat > "${BASE_DIR}/config.json" <<'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "namespace": "RetailPulseMetrics",
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    },
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}"
    }
  }
}
EOF

if [ -f "${AGENT_CONFIG}" ]; then

sudo cp "${BASE_DIR}/config.json" "${AGENT_CONFIG}"

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
-a fetch-config -m ec2 -s \
-c file://"${AGENT_CONFIG}" >/dev/null 2>&1 || true

log "  Agent config deployed"

else

log "  Agent not installed. Config written for lab."

fi
}

###########################################################
# CLOUDWATCH ALARM (BROKEN)
###########################################################
create_cloudwatch_alarms() {

log "Creating CloudWatch alarm..."

aws cloudwatch put-metric-alarm \
--alarm-name "retailpulse-high-memory" \
--metric-name "mem_used_percent" \
--namespace "RetailPulse/AppMetrics" \
--statistic "Average" \
--period 300 \
--evaluation-periods 12 \
--threshold 85 \
--comparison-operator "GreaterThanThreshold" \
--alarm-actions "${SNS_TOPIC_ARN}" \
--region "${REGION}" >/dev/null 2>&1

log "  Alarm created"
}

###########################################################
# LAUNCH TEMPLATE
###########################################################
create_launch_template() {

log "Resolving latest Amazon Linux 2 AMI..."

AMI_ID=$(aws ec2 describe-images \
--owners amazon \
--filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
--query 'sort_by(Images,&CreationDate)[-1].ImageId' \
--output text \
--region "${REGION}")

log "Using AMI ${AMI_ID}"

if aws ec2 describe-launch-templates \
--launch-template-names "${LAUNCH_TEMPLATE_NAME}" \
--region "${REGION}" >/dev/null 2>&1; then

log "  Launch template already exists"
return
fi

aws ec2 create-launch-template \
--launch-template-name "${LAUNCH_TEMPLATE_NAME}" \
--launch-template-data "{
\"ImageId\":\"${AMI_ID}\",
\"InstanceType\":\"t3.micro\"
}" \
--region "${REGION}" >/dev/null 2>&1

log "  Launch template ready"
}

###########################################################
# AUTO SCALING GROUP
###########################################################
###########################################################
# AUTO SCALING GROUP
###########################################################
create_asg() {

log "Ensuring ASG exists..."

if aws autoscaling describe-auto-scaling-groups \
--auto-scaling-group-names "${ASG_NAME}" \
--region "${REGION}" \
--query 'AutoScalingGroups[0].AutoScalingGroupName' \
--output text 2>/dev/null | grep -q "${ASG_NAME}"; then

log "  ASG already exists"
return

fi

log "Resolving subnets..."

SUBNETS=$(aws ec2 describe-subnets \
--region "${REGION}" \
--query 'Subnets[0:2].SubnetId' \
--output text | tr '\t' ',')

if [ -z "${SUBNETS}" ]; then
  log "ERROR: No subnets found in region ${REGION}"
  return
fi

log "Using subnets: ${SUBNETS}"

aws autoscaling create-auto-scaling-group \
--auto-scaling-group-name "${ASG_NAME}" \
--launch-template "LaunchTemplateName=${LAUNCH_TEMPLATE_NAME},Version=\$Latest" \
--min-size 0 \
--max-size 3 \
--desired-capacity 0 \
--vpc-zone-identifier "${SUBNETS}" \
--region "${REGION}" >/dev/null 2>&1 || log "WARNING: ASG creation failed"

log "  ASG ready"
}

###########################################################
# SCALING POLICY (BROKEN)
###########################################################
create_asg_policy() {

log "Creating scaling policy..."

if ! aws autoscaling describe-auto-scaling-groups \
--auto-scaling-group-names "${ASG_NAME}" \
--region "${REGION}" \
--query 'AutoScalingGroups[0].AutoScalingGroupName' \
--output text 2>/dev/null | grep -q "${ASG_NAME}"; then

log "WARNING: ASG missing, skipping scaling policy"
return
fi

cat > "${BASE_DIR}/asg-policy.json" <<'EOF'
{
"TargetValue":70.0,
"PredefinedMetricSpecification":{
"PredefinedMetricType":"ASGAverageCPUUtilization"
}
}
EOF

aws autoscaling put-scaling-policy \
--auto-scaling-group-name "${ASG_NAME}" \
--policy-name "retailpulse-target-tracking" \
--policy-type "TargetTrackingScaling" \
--target-tracking-configuration file://"${BASE_DIR}/asg-policy.json" \
--region "${REGION}" >/dev/null 2>&1

log "  Scaling policy ready"
}

###########################################################
# INFO FILE
###########################################################
create_imp_info_file() {

cat > "${HOME_DIR}/imp_info.txt" <<EOF
RetailPulse CloudWatch Lab Ready

Account: ${ACCOUNT_ID}
Region: ${REGION}

IAM Role: ${EC2_ROLE}
ASG: ${ASG_NAME}

There are 4 bugs to fix.
EOF
}

###########################################################
# MAIN
###########################################################
main() {

echo "Setting up RetailPulse CloudWatch Lab..."

create_iam_role
create_iam_policy
create_sns_topic
create_agent_config
create_cloudwatch_alarms
create_launch_template
create_asg
create_asg_policy
create_imp_info_file

echo ""
echo "RetailPulse CloudWatch Lab ready"
}

main

chown -R user:user "${BASE_DIR}"
