#!/bin/bash
# solution.sh
# Applies all five fixes to the NovaPay ECR lab environment.
# Run as: bash solution.sh

set -euo pipefail
export AWS_PAGER=""

BASE_DIR="/home/user/novapay-ecr-lab"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"
NODE_ROLE="novapay-eks-node-role"
CICD_ROLE="novapay-cicd-role"
NODE_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${NODE_ROLE}"
CICD_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${CICD_ROLE}"

mkdir -p "${BASE_DIR}/fixed"

echo "============================================================"
echo "  NOVAPAY ECR LAB — APPLYING FIXES"
echo "============================================================"
echo ""

# --------------------------------------------------
# FIX 1: Add ecr:GetAuthorizationToken to node IAM inline policy
#
# Root cause: The inline policy was missing GetAuthorizationToken.
# This is an IAM-level action (not a repository action) that nodes
# must call first to receive a temporary Docker login token.
# Without it every ECR pull on every repository fails immediately
# with "no basic auth credentials".
# --------------------------------------------------
echo "[Fix 1/5] Adding ecr:GetAuthorizationToken to node role inline policy..."

cat > "${BASE_DIR}/fixed/node-ecr-policy.json" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAuthToken",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECRPullAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name "${NODE_ROLE}" \
    --policy-name "novapay-eks-node-ecr-policy" \
    --policy-document file://"${BASE_DIR}/fixed/node-ecr-policy.json"

echo "  Done: ecr:GetAuthorizationToken added to novapay-eks-node-ecr-policy"
echo ""

# --------------------------------------------------
# FIX 2: Add missing ecr:BatchGetImage to payment-processor NodePull statement
#
# Root cause: The NodePull statement for the node role was missing
# ecr:BatchGetImage — the action that fetches the image manifest.
# Without it ECR denied the manifest fetch mid-pull with AccessDenied,
# causing pods to enter ImagePullBackOff even though authentication
# itself succeeded.
# --------------------------------------------------
echo "[Fix 2/5] Adding ecr:BatchGetImage to novapay/payment-processor NodePull statement..."

cat > "${BASE_DIR}/fixed/policy-payment-processor.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "NodePull",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${NODE_ROLE_ARN}"
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
    },
    {
      "Sid": "CICDPush",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${CICD_ROLE_ARN}"
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ]
    }
  ]
}
EOF

aws ecr set-repository-policy \
    --repository-name "novapay/payment-processor" \
    --policy-text file://"${BASE_DIR}/fixed/policy-payment-processor.json" \
    --region "${REGION}"

echo "  Done: ecr:BatchGetImage added to NodePull in novapay/payment-processor"
echo ""

# --------------------------------------------------
# FIX 3: Add CI/CD push actions to fraud-detection repository policy
#
# Root cause: The CICDAccess statement only had the three read/pull
# actions. The four push actions were missing entirely. docker push
# failed at the layer upload stage with "authorization failed".
# --------------------------------------------------
echo "[Fix 3/5] Adding CI/CD push actions to novapay/fraud-detection repository policy..."

cat > "${BASE_DIR}/fixed/policy-fraud-detection.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "NodePull",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${NODE_ROLE_ARN}"
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
    },
    {
      "Sid": "CICDPush",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${CICD_ROLE_ARN}"
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ]
    }
  ]
}
EOF

aws ecr set-repository-policy \
    --repository-name "novapay/fraud-detection" \
    --policy-text file://"${BASE_DIR}/fixed/policy-fraud-detection.json" \
    --region "${REGION}"

echo "  Done: push actions added to CICDPush in novapay/fraud-detection"
echo ""

# --------------------------------------------------
# FIX 4: Add node role principal to batch-runner repository policy
#
# Root cause: The batch-runner repository policy only listed the
# CI/CD role. The node role was absent entirely — every EKS node
# pull request was denied. Pods entered ImagePullBackOff on every
# new scheduling event.
# --------------------------------------------------
echo "[Fix 4/5] Adding node role principal to novapay/batch-runner repository policy..."

cat > "${BASE_DIR}/fixed/policy-batch-runner.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "NodePull",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${NODE_ROLE_ARN}"
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
    },
    {
      "Sid": "CICDPush",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${CICD_ROLE_ARN}"
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ]
    }
  ]
}
EOF

aws ecr set-repository-policy \
    --repository-name "novapay/batch-runner" \
    --policy-text file://"${BASE_DIR}/fixed/policy-batch-runner.json" \
    --region "${REGION}"

echo "  Done: node role NodePull statement added to novapay/batch-runner"
echo ""

# --------------------------------------------------
# FIX 5: Correct the fraud-detection lifecycle policy
#
# Root cause (three wrong fields):
#   tagStatus: 'any'                → 'untagged'
#   countType: 'imageCountMoreThan' → 'sinceImagePushed'
#   countNumber: 1                  → 30
#   countUnit: (missing)            → 'days'
#
# Effect of broken policy: every image in the repo (including
# actively tagged production images) was deleted the moment a
# second image was pushed — wiping production tags and causing
# cascading pull failures across the cluster.
# --------------------------------------------------
echo "[Fix 5/5] Correcting lifecycle policy on novapay/fraud-detection..."

cat > "${BASE_DIR}/fixed/lifecycle-fraud-detection.json" <<'EOF'
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images older than 30 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countNumber": 30,
        "countUnit": "days"
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF

aws ecr put-lifecycle-policy \
    --repository-name "novapay/fraud-detection" \
    --lifecycle-policy-text file://"${BASE_DIR}/fixed/lifecycle-fraud-detection.json" \
    --region "${REGION}"

echo "  Done: lifecycle policy corrected — untagged images expire after 30 days"
echo ""

# --------------------------------------------------
# Summary
# --------------------------------------------------
echo "============================================================"
echo "  ALL FIXES APPLIED"
echo "============================================================"
echo ""
echo "  Fix 1: Node IAM inline policy"
echo "         Added ecr:GetAuthorizationToken"
echo ""
echo "  Fix 2: novapay/payment-processor repository policy"
echo "         Added missing ecr:BatchGetImage to NodePull statement"
echo ""
echo "  Fix 3: novapay/fraud-detection repository policy"
echo "         Added push actions for CI/CD role"
echo "         (PutImage, InitiateLayerUpload, UploadLayerPart, CompleteLayerUpload)"
echo ""
echo "  Fix 4: novapay/batch-runner repository policy"
echo "         Added node role NodePull statement with all three pull actions"
echo ""
echo "  Fix 5: novapay/fraud-detection lifecycle policy"
echo "         tagStatus:   any                → untagged"
echo "         countType:   imageCountMoreThan → sinceImagePushed"
echo "         countNumber: 1                  → 30"
echo "         countUnit:   (missing)          → days"
echo ""
echo "  Verify with:"
echo "    aws iam get-role-policy --role-name ${NODE_ROLE} --policy-name novapay-eks-node-ecr-policy"
echo "    aws ecr get-repository-policy --repository-name novapay/payment-processor --region ${REGION}"
echo "    aws ecr get-repository-policy --repository-name novapay/batch-runner --region ${REGION}"
echo "    aws ecr get-repository-policy --repository-name novapay/fraud-detection --region ${REGION}"
echo "    aws ecr get-lifecycle-policy --repository-name novapay/fraud-detection --region ${REGION}"
echo "============================================================"