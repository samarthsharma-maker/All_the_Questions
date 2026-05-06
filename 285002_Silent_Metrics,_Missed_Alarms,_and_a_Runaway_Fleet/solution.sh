#!/bin/bash
# solution.sh

set -uo pipefail
export AWS_PAGER=""

BASE_DIR="/home/user/retailpulse-lab"
REGION="us-west-2"
EC2_ROLE="retailpulse-ec2-role"
POLICY_NAME="retailpulse-cloudwatch-policy"
ASG_NAME="retailpulse-app-asg"
AGENT_CONFIG="/opt/aws/amazon-cloudwatch-agent/bin/config.json"

mkdir -p "${BASE_DIR}/fixed"

echo "============================================================"
echo "  RETAILPULSE CLOUDWATCH LAB — APPLYING FIXES"
echo "============================================================"
echo ""

############################################################
# FIX 1 — IAM POLICY
############################################################
echo "[Fix 1/4] Adding cloudwatch:PutMetricData..."

cat > "${BASE_DIR}/fixed/cloudwatch-policy.json" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchAgentAccess",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
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
--policy-document file://"${BASE_DIR}/fixed/cloudwatch-policy.json"

echo "  Done"
echo ""

############################################################
# FIX 2 — AGENT CONFIG
############################################################
echo "[Fix 2/4] Correcting CloudWatch namespace..."

cat > "${BASE_DIR}/fixed/config.json" <<'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "namespace": "RetailPulse/AppMetrics",
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ]
      }
    },
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}"
    }
  }
}
EOF

cp "${BASE_DIR}/fixed/config.json" "${BASE_DIR}/config.json"

if [ -f "${AGENT_CONFIG}" ]; then
sudo cp "${BASE_DIR}/fixed/config.json" "${AGENT_CONFIG}"

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
-a fetch-config -m ec2 -s \
-c file://"${AGENT_CONFIG}" >/dev/null 2>&1 || true

echo "  Agent reloaded"
else
echo "  Config updated in lab folder"
fi

echo ""

############################################################
# FIX 3 — ALARM
############################################################
echo "[Fix 3/4] Fixing alarm evaluation periods..."

aws cloudwatch put-metric-alarm \
--alarm-name "retailpulse-high-memory" \
--metric-name "mem_used_percent" \
--namespace "RetailPulse/AppMetrics" \
--statistic "Average" \
--period 300 \
--evaluation-periods 2 \
--threshold 85 \
--comparison-operator "GreaterThanThreshold" \
--region "${REGION}"

echo "  Done"
echo ""

############################################################
# FIX 4 — SCALING POLICY
############################################################
echo "[Fix 4/4] Updating Auto Scaling scaling policy..."

if aws autoscaling describe-auto-scaling-groups \
--auto-scaling-group-names "${ASG_NAME}" \
--region "${REGION}" \
--query 'AutoScalingGroups[0].AutoScalingGroupName' \
--output text 2>/dev/null | grep -q "${ASG_NAME}"
then

cat > "${BASE_DIR}/fixed/asg-policy.json" <<'EOF'
{
  "TargetValue": 1000.0,
  "CustomizedMetricSpecification": {
    "MetricName": "RequestsPerTarget",
    "Namespace": "AWS/ApplicationELB",
    "Statistic": "Average"
  }
}
EOF

aws autoscaling put-scaling-policy \
--auto-scaling-group-name "${ASG_NAME}" \
--policy-name "retailpulse-target-tracking" \
--policy-type "TargetTrackingScaling" \
--target-tracking-configuration file://"${BASE_DIR}/fixed/asg-policy.json" \
--region "${REGION}" --no-cli-pager

echo "  Done"

else
echo "  WARNING: ASG not found — setup likely failed"
fi

echo ""
echo "============================================================"
echo "  ALL FIXES APPLIED"
echo "============================================================"
