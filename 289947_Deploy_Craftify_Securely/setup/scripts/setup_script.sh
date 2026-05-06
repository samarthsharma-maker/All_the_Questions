#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
LAB_DIR="/home/user/craftify-eks-lab"
ECR_REPO_NAME="craftify-app"
BUCKET_NAME="craftify-assets-${ACCOUNT_ID}"
CLUSTER_NAME="craftify-cluster"

mkdir -p "$LAB_DIR"

echo "Installing dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get update -qq > /dev/null 2>&1 || true
DEBIAN_FRONTEND=noninteractive apt-get install -y -q jq zip curl > /dev/null 2>&1 || \
    yum install -y -q jq zip curl > /dev/null 2>&1 || true

echo "Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" > /dev/null 2>&1
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
fi

# Get default VPC and subnets
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text --region "$REGION")

SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=defaultForAz,Values=true" \
    --query "Subnets[?AvailabilityZone!='us-west-2d'].SubnetId" \
    --output text --region "$REGION" | tr '\t' ',')

# STEP 1 FIRST: Fire EKS cluster creation in background immediately
echo "Starting EKS cluster creation in background..."

aws iam get-role --role-name "craftify-eks-cluster-role" > /dev/null 2>&1 || \
aws iam create-role \
    --role-name "craftify-eks-cluster-role" \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"eks.amazonaws.com"},"Action":"sts:AssumeRole"}]}' > /dev/null

aws iam attach-role-policy \
    --role-name "craftify-eks-cluster-role" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" 2>/dev/null || true

CLUSTER_ROLE_ARN=$(aws iam get-role \
    --role-name "craftify-eks-cluster-role" \
    --query "Role.Arn" \
    --output text)

SUBNET_PAIR=$(echo $SUBNET_IDS | tr ',' ' ' | awk '{print $1","$2}')

aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" > /dev/null 2>&1 || \
nohup aws eks create-cluster \
    --name "$CLUSTER_NAME" \
    --role-arn "$CLUSTER_ROLE_ARN" \
    --resources-vpc-config "subnetIds=${SUBNET_PAIR},endpointPublicAccess=true" \
    --region "$REGION" > /tmp/eks-create.log 2>&1 &

echo "EKS cluster creation started in background (PID: $!)."

# STEP 2: Create ECR repository
echo "Creating ECR repository..."
aws ecr describe-repositories \
    --repository-names "$ECR_REPO_NAME" \
    --region "$REGION" > /dev/null 2>&1 || \
aws ecr create-repository \
    --repository-name "$ECR_REPO_NAME" \
    --region "$REGION" > /dev/null

ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_NAME}"

# STEP 3: Create S3 bucket and upload config
echo "Creating S3 bucket..."
aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null || \
aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" > /dev/null

cat > /tmp/app-config.json << 'EOF'
{
  "app_name": "craftify-platform",
  "version": "3.0.0",
  "features": {
    "live_sessions": true,
    "ai_mentor": true,
    "peer_review": true
  },
  "db_pool_size": 10,
  "cache_ttl": 300
}
EOF

aws s3 cp /tmp/app-config.json "s3://${BUCKET_NAME}/config/app-config.json" --region "$REGION" > /dev/null

# STEP 4: Write lab files
echo "Writing lab files..."

cat > "$LAB_DIR/Dockerfile" << 'EOF'
FROM node:latest

RUN apt-get update && apt-get install -y \
    telnet \
    wget \
    vim \
    net-tools \
    build-essential

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

CMD ["node", "server.js"]
EOF

cat > "$LAB_DIR/server.js" << 'EOF'
const http = require('http');
const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3');

const s3 = new S3Client({ region: process.env.AWS_REGION || 'us-west-2' });
const BUCKET = process.env.S3_BUCKET || '';

const server = http.createServer(async (req, res) => {
    if (req.url === '/health') {
        res.writeHead(200);
        res.end('OK');
        return;
    }

    if (req.url === '/config' && BUCKET) {
        try {
            const cmd = new GetObjectCommand({
                Bucket: BUCKET,
                Key: 'config/app-config.json'
            });
            const data = await s3.send(cmd);
            const body = await data.Body.transformToString();
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(body);
        } catch (e) {
            res.writeHead(500);
            res.end(JSON.stringify({ error: e.message }));
        }
        return;
    }

    res.writeHead(200);
    res.end(JSON.stringify({ service: 'craftify-platform', status: 'running' }));
});

server.listen(3000, () => console.log('Craftify app listening on port 3000'));
EOF

cat > "$LAB_DIR/package.json" << 'EOF'
{
  "name": "craftify-platform",
  "version": "3.0.0",
  "main": "server.js",
  "dependencies": {
    "@aws-sdk/client-s3": "^3.0.0"
  }
}
EOF

cat > "$LAB_DIR/deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: craftify-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: craftify
  template:
    metadata:
      labels:
        app: craftify
    spec:
      containers:
        - name: craftify
          image: ${ECR_URI}:hardened
          ports:
            - containerPort: 3000
          env:
            - name: AWS_REGION
              value: "${REGION}"
            - name: S3_BUCKET
              value: "${BUCKET_NAME}"
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 10
EOF

# Save config
cat > "$LAB_DIR/lab-config.txt" << EOF
ACCOUNT_ID=$ACCOUNT_ID
REGION=$REGION
ECR_URI=$ECR_URI
ECR_REPO_NAME=$ECR_REPO_NAME
BUCKET_NAME=$BUCKET_NAME
CLUSTER_NAME=$CLUSTER_NAME
VPC_ID=$VPC_ID
SUBNET_IDS=$SUBNET_IDS
EOF

chown -R user:user "$LAB_DIR"

echo ""
echo "========================================="
echo "  Craftify EKS Lab Environment Ready"
echo "========================================="
echo ""
echo "ECR repository : $ECR_URI"
echo "S3 bucket      : $BUCKET_NAME"
echo "EKS cluster    : $CLUSTER_NAME (provisioning in background)"
echo ""
echo "Files in $LAB_DIR:"
echo "  Dockerfile      -- insecure, needs hardening"
echo "  server.js       -- application code"
echo "  package.json    -- dependencies"
echo "  deployment.yaml -- Kubernetes deployment template"
echo ""
echo "!!! EKS cluster is being provisioned in the background."
echo "    Start with Dockerfile hardening and ECR push while you wait."
echo "    Cluster will be ready in approximately 15-20 minutes."
echo "    Check status: aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.status' --output text --region $REGION"
echo ""