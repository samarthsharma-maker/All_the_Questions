#!/bin/bash
# setup-ecr-lab.sh
# Creates the broken NovaPay ECR lab environment.
# Simulates IAM and ECR resources using local JSON files + AWS CLI.
# Run as: bash setup-ecr-lab.sh

set -euo pipefail
export AWS_PAGER=""

HOME_DIR="/home/user"
BASE_DIR="/home/user/novapay-ecr-lab"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"
NODE_ROLE="novapay-eks-node-role"
CICD_ROLE="novapay-cicd-role"

mkdir -p "${BASE_DIR}"

# --------------------------------------------------
# Helper
# --------------------------------------------------
function log() { echo "[setup] $*"; }

# --------------------------------------------------
# IAM Roles (stubs — created only if they do not exist)
# These represent the EKS node role and CI/CD role.
# In a real cluster these are created by the EKS module.
# --------------------------------------------------
function create_iam_roles() {
    log "Ensuring IAM roles exist..."

    local trust_policy
    trust_policy='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

    aws iam create-role --role-name "${NODE_ROLE}" --assume-role-policy-document "${trust_policy}" --region "${REGION}" 2>/dev/null || log "  ${NODE_ROLE} already exists, skipping."
    aws iam create-role --role-name "${CICD_ROLE}" --assume-role-policy-document "${trust_policy}" --region "${REGION}" 2>/dev/null || log "  ${CICD_ROLE} already exists, skipping."
}

# --------------------------------------------------
# Node IAM Role Inline Policy (BROKEN)
#
# BUG 1 — Missing ecr:GetAuthorizationToken.
# Without this action nodes cannot obtain a Docker login
# token. Every ECR pull fails with "no basic auth credentials"
# regardless of what the repository policy allows.
# --------------------------------------------------
function create_node_iam_policy() {
    log "Attaching broken inline policy to ${NODE_ROLE}..."

    cat > "${BASE_DIR}/node-ecr-policy.json" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
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
    aws iam put-role-policy --role-name "${NODE_ROLE}" --policy-name "novapay-eks-node-ecr-policy" --policy-document file://"${BASE_DIR}/node-ecr-policy.json" --region "${REGION}"
}

# --------------------------------------------------
# ECR Repositories
# --------------------------------------------------
function create_ecr_repositories() {
    log "Creating ECR repositories..."
    for repo in novapay/payment-processor novapay/batch-runner novapay/fraud-detection; do
        aws ecr create-repository --repository-name "${repo}" --region "${REGION}" 2>/dev/null || log "  ${repo} already exists, skipping."
    done
}

# --------------------------------------------------
# ECR Repository Policies (BROKEN)
#
# BUG 2 — payment-processor: node role pull statement is missing
#   ecr:BatchGetImage. ECR requires all three pull actions together.
#   Without BatchGetImage the image manifest cannot be fetched —
#   nodes receive AccessDenied mid-pull and enter ImagePullBackOff.
#
# BUG 3 — fraud-detection: CI/CD role is granted only pull
#   actions (read-only). The four push actions are missing.
#   docker push returns "authorization failed" at layer upload.
#
# BUG 4 — batch-runner: node role principal is absent entirely.
#   Only the CI/CD role is listed. Nodes cannot pull batch-runner
#   images even though GetAuthorizationToken works.
# --------------------------------------------------
function create_ecr_repository_policies() {
    log "Applying broken ECR repository policies..."

    # ---- payment-processor (BUG 2) ----
    # ecr:BatchGetImage is intentionally omitted from the node pull statement.
    cat > "${BASE_DIR}/policy-payment-processor.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "NodePull",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${ACCOUNT_ID}:role/${NODE_ROLE}"
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchCheckLayerAvailability"
      ]
    },
    {
      "Sid": "CICDPush",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${ACCOUNT_ID}:role/${CICD_ROLE}"
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

    # ---- batch-runner (BUG 4) ----
    cat > "${BASE_DIR}/policy-batch-runner.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CICDPush",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${ACCOUNT_ID}:role/${CICD_ROLE}"
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
    # Node role is intentionally absent from batch-runner policy above.

    # ---- fraud-detection (BUG 3) ----
    cat > "${BASE_DIR}/policy-fraud-detection.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "NodePull",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${ACCOUNT_ID}:role/${NODE_ROLE}"
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
    },
    {
      "Sid": "CICDAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${ACCOUNT_ID}:role/${CICD_ROLE}"
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
    }
  ]
}
EOF
    # Push actions (PutImage, InitiateLayerUpload, UploadLayerPart,
    # CompleteLayerUpload) are intentionally missing from CICDAccess above.

    for repo in payment-processor batch-runner fraud-detection; do
        aws ecr set-repository-policy --repository-name "novapay/${repo}" --policy-text file://"${BASE_DIR}/policy-${repo}.json" --region "${REGION}"
        log "  Applied policy to novapay/${repo}"
    done
}

# --------------------------------------------------
# ECR Lifecycle Policy (BROKEN)
#
# BUG 5 — fraud-detection lifecycle policy:
#   tagStatus is 'any' instead of 'untagged'
#   countType is 'imageCountMoreThan' instead of 'sinceImagePushed'
#   countNumber is 1 instead of 30
#   countUnit is missing (required for sinceImagePushed)
#
# Effect: deletes ALL images (tagged + untagged) once the repo
# holds more than 1 image — wiping actively used production tags.
# --------------------------------------------------
function create_ecr_lifecycle_policy() {
    log "Applying broken lifecycle policy to novapay/fraud-detection..."

    cat > "${BASE_DIR}/lifecycle-fraud-detection.json" <<'EOF'
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire old untagged images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 1
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
    # tagStatus should be 'untagged'
    # countType should be 'sinceImagePushed'
    # countNumber should be 30
    # countUnit: "days" is required but absent

    aws ecr put-lifecycle-policy --repository-name "novapay/fraud-detection" --lifecycle-policy-text file://"${BASE_DIR}/lifecycle-fraud-detection.json" --region "${REGION}"
    log "  Applied lifecycle policy to novapay/fraud-detection"
}

# --------------------------------------------------
# Create Important Info File
#
# Generates an imp_info.txt file at home directory
# containing environment setup information and useful commands.
# --------------------------------------------------
function create_imp_info_file() {
    log "Creating imp_info.txt at ${HOME_DIR}..."

    cat > "${HOME_DIR}/imp_info.txt" <<EOF

============================================================
  NOVAPAY ECR LAB — ENVIRONMENT READY
============================================================

  Account:  ${ACCOUNT_ID}   Region: ${REGION}

  IAM role (node):  ${NODE_ROLE}
  IAM role (ci/cd): ${CICD_ROLE}

  ECR repositories:
    novapay/payment-processor
    novapay/batch-runner
    novapay/fraud-detection

  Policy files written to: ${BASE_DIR}/

  There are 5 bugs across these resources.
  Find and fix them all.

  Useful commands:
    aws iam get-role-policy --role-name ${NODE_ROLE} --policy-name novapay-eks-node-ecr-policy
    aws ecr get-repository-policy --repository-name novapay/payment-processor --region ${REGION}
    aws ecr get-repository-policy --repository-name novapay/batch-runner --region ${REGION}
    aws ecr get-repository-policy --repository-name novapay/fraud-detection --region ${REGION}
    aws ecr get-lifecycle-policy --repository-name novapay/fraud-detection --region ${REGION}
============================================================
EOF
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "Setting up NovaPay ECR Lab..."
    echo ""

    echo "[1/6] Creating IAM roles (stubs)..."
    create_iam_roles

    echo "[2/6] Attaching broken node IAM inline policy..."
    create_node_iam_policy

    echo "[3/6] Creating ECR repositories..."
    create_ecr_repositories

    echo "[4/6] Applying broken ECR repository policies..."
    create_ecr_repository_policies

    echo "[5/6] Applying broken ECR lifecycle policy..."
    create_ecr_lifecycle_policy

    echo "[6/6] Creating important info file..."
    create_imp_info_file

    echo ""
    echo "============================================================"
    echo "  NOVAPAY ECR LAB — ENVIRONMENT READY"
    echo "============================================================"
    echo ""
    echo "  Account:  ${ACCOUNT_ID}   Region: ${REGION}"
    echo ""
    echo "  IAM role (node):  ${NODE_ROLE}"
    echo "  IAM role (ci/cd): ${CICD_ROLE}"
    echo ""
    echo "  ECR repositories:"
    echo "    novapay/payment-processor"
    echo "    novapay/batch-runner"
    echo "    novapay/fraud-detection"
    echo ""
    echo "  Policy files written to: ${BASE_DIR}/"
    echo ""
    echo "  There are 5 bugs across these resources."
    echo "  Find and fix them all."
    echo ""
    echo "  Useful commands:"
    echo "    aws iam get-role-policy --role-name ${NODE_ROLE} --policy-name novapay-eks-node-ecr-policy"
    echo "    aws ecr get-repository-policy --repository-name novapay/payment-processor --region ${REGION}"
    echo "    aws ecr get-repository-policy --repository-name novapay/batch-runner --region ${REGION}"
    echo "    aws ecr get-repository-policy --repository-name novapay/fraud-detection --region ${REGION}"
    echo "    aws ecr get-lifecycle-policy --repository-name novapay/fraud-detection --region ${REGION}"
    echo "============================================================"
}

main

chown -R user:user "${BASE_DIR}"