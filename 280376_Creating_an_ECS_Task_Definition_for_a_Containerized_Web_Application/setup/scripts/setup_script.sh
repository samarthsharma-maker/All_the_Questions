#!/bin/bash

set -euo pipefail
BASE_DIR="/home/user/app"
REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Setting up prerequisite resources in region: ${REGION}"
echo "Account ID: ${ACCOUNT_ID}"
echo ""


echo "[1/6] Creating CloudWatch Log Group..."
LOG_GROUP="${BASE_DIR}/ecs/payment-processor"

aws logs create-log-group --log-group-name "$LOG_GROUP" --region "$REGION" 2>/dev/null || echo "  Log group already exists"
aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 7 --region "$REGION" 2>/dev/null || true

echo "CloudWatch Log Group created: $LOG_GROUP"

echo "[2/6] Creating ECR Repository..."
REPO_NAME="payment-processor"

aws ecr create-repository --repository-name "$REPO_NAME" --region "$REGION" --image-scanning-configuration scanOnPush=true --encryption-configuration encryptionType=AES256 2>/dev/null || echo "  Repository already exists"
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}"

echo "ECR Repository created: $REPO_NAME"
echo "[3/6] Building application Docker image..."

mkdir -p ${BASE_DIR}/payment-app

cat > ${BASE_DIR}/payment-app/package.json <<'EOF'
{
  "name": "payment-processor",
  "version": "1.0.0",
  "description": "Payment processing microservice",
  "main": "app.js",
  "dependencies": {
    "express": "^4.18.2"
  },
  "scripts": {
    "start": "node app.js"
  }
}
EOF

cat > ${BASE_DIR}/payment-app/app.js <<'EOF'
const express = require('express');
const app = express();

const PORT = process.env.PORT || 8080;
const SERVICE_NAME = process.env.SERVICE_NAME || 'payment-processor';
const ENVIRONMENT = process.env.ENVIRONMENT || 'development';

app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: SERVICE_NAME,
    environment: ENVIRONMENT,
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    service: SERVICE_NAME,
    version: '1.0.0',
    environment: ENVIRONMENT,
    message: 'Payment Processor Service is running',
    endpoints: {
      health: '/health',
      process: '/process',
      status: '/status'
    }
  });
});

// Process payment endpoint
app.post('/process', (req, res) => {
  const { amount, currency, customer } = req.body;
  
  console.log(`Processing payment: ${amount} ${currency} for customer ${customer}`);
  
  res.status(200).json({
    status: 'success',
    transactionId: `txn_${Date.now()}`,
    amount: amount,
    currency: currency,
    timestamp: new Date().toISOString()
  });
});

// Status endpoint
app.get('/status', (req, res) => {
  res.json({
    service: SERVICE_NAME,
    status: 'operational',
    environment: ENVIRONMENT,
    memory: process.memoryUsage(),
    uptime: process.uptime()
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`${SERVICE_NAME} listening on port ${PORT}`);
  console.log(`Environment: ${ENVIRONMENT}`);
  console.log(`Started at: ${new Date().toISOString()}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});
EOF

# Create Dockerfile
cat > ${BASE_DIR}/payment-app/Dockerfile <<'EOF'
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json ./

# Install production dependencies
RUN npm install --production --silent

# Copy application code
COPY app.js ./

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start application
CMD ["node", "app.js"]
EOF

echo "  Authenticating with ECR..."
aws ecr get-login-password --region "$REGION" | \
    docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com" 2>/dev/null

cd ${BASE_DIR}/payment-app
docker build -t "$REPO_NAME:latest" . --quiet

docker tag "$REPO_NAME:latest" "${ECR_URI}:latest"
docker tag "$REPO_NAME:latest" "${ECR_URI}:v1.0.0"

docker push "${ECR_URI}:latest" --quiet
docker push "${ECR_URI}:v1.0.0" --quiet

echo "[4/6] Creating ECS Task Execution Role..."

cat > /tmp/task-execution-trust-policy.json <<'TRUST'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
TRUST

aws iam create-role --role-name PaymentProcessorExecutionRole --assume-role-policy-document file:///tmp/task-execution-trust-policy.json --description "Allows ECS tasks to pull images and write logs" --tags Key=Application,Value=PaymentProcessor \
    2>/dev/null || echo "  Role already exists"

aws iam attach-role-policy --role-name PaymentProcessorExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
    2>/dev/null || echo "  Policy already attached"

EXECUTION_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/PaymentProcessorExecutionRole"

echo "Task Execution Role created: PaymentProcessorExecutionRole"
echo "[5/6] Creating ECS Task Role..."

cat > /tmp/task-role-trust-policy.json <<'TRUST'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
TRUST

aws iam create-role --role-name PaymentProcessorTaskRole --assume-role-policy-document file:///tmp/task-role-trust-policy.json --description "IAM role for payment processor application runtime" --tags Key=Application,Value=PaymentProcessor \
    2>/dev/null || echo "  Role already exists"

TASK_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/PaymentProcessorTaskRole"

echo "[6/6] Getting VPC information..."

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --region "$REGION" --query 'Vpcs[0].VpcId' --output text)

SUBNET_1=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --region "$REGION" --query 'Subnets[0].SubnetId' --output text)
SUBNET_2=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --region "$REGION" --query 'Subnets[1].SubnetId' --output text)

cat > /tmp/ecs_lab_env.txt <<ENV
# ECS Task Definition Lab Environment Variables
# Source this file: source /tmp/ecs_lab_env.txt

REGION=$REGION
ACCOUNT_ID=$ACCOUNT_ID
ECR_REPO_NAME=$REPO_NAME
ECR_IMAGE_URI=${ECR_URI}:latest
LOG_GROUP=$LOG_GROUP
EXECUTION_ROLE_ARN=$EXECUTION_ROLE_ARN
TASK_ROLE_ARN=$TASK_ROLE_ARN
VPC_ID=$VPC_ID
SUBNET_1=$SUBNET_1
SUBNET_2=$SUBNET_2
ENV

echo ""
echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo ""
echo "Resources created:"
echo "  ✓ ECR Repository: $REPO_NAME"
echo "  ✓ Docker Image: ${ECR_URI}:latest"
echo "  ✓ CloudWatch Log Group: $LOG_GROUP"
echo "  ✓ Task Execution Role: PaymentProcessorExecutionRole"
echo "  ✓ Task Role: PaymentProcessorTaskRole"
echo ""
echo "Environment variables saved to: /tmp/ecs_lab_env.txt"

echo "================================================"

# Cleanup temporary files
rm -rf  /tmp/task-execution-trust-policy.json /tmp/task-role-trust-policy.json
chown -R user:user ${BASE_DIR} 
