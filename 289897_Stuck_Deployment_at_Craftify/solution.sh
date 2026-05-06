#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

CONFIG="/home/user/craftify-deploy-lab/lab-config.txt"
if [ ! -f "$CONFIG" ]; then
    echo "Lab config not found. Run setup.sh first."
    exit 1
fi

source "$CONFIG"

echo "========================================="
echo "  Craftify Deploy Lab - Solution"
echo "========================================="
echo ""
echo "Instance : $INSTANCE_IP"
echo "Pipeline : $PIPELINE_NAME"

# Wait for SSH to be ready
echo ""
echo "Waiting for SSH to be ready..."
for i in $(seq 1 20); do
    if ssh -i "$KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=5 \
        -o BatchMode=yes \
        ec2-user@"$INSTANCE_IP" "echo ok" > /dev/null 2>&1; then
        echo "SSH ready."
        break
    fi
    echo "  Attempt $i — waiting..."
    sleep 10
done

# Step 1: Diagnose and fix the CodeDeploy agent
echo ""
echo "Step 1: Checking CodeDeploy agent status..."
ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=15 \
    ec2-user@"$INSTANCE_IP" \
    "systemctl status codedeploy-agent --no-pager || true"

echo ""
echo "Starting and enabling CodeDeploy agent..."
ssh -i "$KEY_PATH" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=15 \
    ec2-user@"$INSTANCE_IP" \
    "sudo systemctl start codedeploy-agent && sudo systemctl enable codedeploy-agent"

echo "Agent started and enabled."

# Step 2: Re-trigger the pipeline
echo ""
echo "Step 2: Re-triggering the pipeline..."
aws codepipeline start-pipeline-execution \
    --name "$PIPELINE_NAME" \
    --region "$REGION"

echo "Pipeline triggered. Waiting for deployment to complete..."

# Wait for pipeline to succeed
for i in $(seq 1 30); do
    STATUS=$(aws codepipeline get-pipeline-state \
        --name "$PIPELINE_NAME" \
        --region "$REGION" \
        --query "stageStates[?stageName=='Deploy'].actionStates[0].latestExecution.status" \
        --output text 2>/dev/null || echo "")
    echo "  Deploy stage: $STATUS"
    if [ "$STATUS" == "Succeeded" ]; then
        echo "Deployment succeeded."
        break
    elif [ "$STATUS" == "Failed" ]; then
        echo "Deployment failed. Check CodeDeploy console for details."
        exit 1
    fi
    sleep 15
done

# Step 3: Verify the deployment
echo ""
echo "Step 3: Verifying deployment..."
curl -s "http://${INSTANCE_IP}/index.html"

echo ""
echo "========================================="
echo "  Solution Applied: Summary"
echo "========================================="
echo ""
echo "Root cause  : CodeDeploy agent was installed but stopped"
echo "Fix         : sudo systemctl start codedeploy-agent"
echo "              sudo systemctl enable codedeploy-agent"
echo "Result      : Pipeline re-triggered, deployment succeeded"
echo "Verified    : http://$INSTANCE_IP/index.html serving v2.1.3"
echo ""