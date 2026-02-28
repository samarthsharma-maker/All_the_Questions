#!/bin/bash

set -euo pipefail

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/pipeline.sh"

# Ensure target directory exists
mkdir -p "$TARGET_DIR"

# Create the pipeline script
cat > "$TARGET_FILE" << 'EOF'
#!/bin/bash

set -euo pipefail

TARGET_DIR="/home/user"
DATA_DIR="${TARGET_DIR}/salary_data"

sudo apt update
sudo apt install -y zip

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"

UPLOAD_BUCKET="salary-file-uploads-${ACCOUNT_ID}"
PROCESSED_BUCKET="salary-processed-bucket-${ACCOUNT_ID}"
LAMBDA_NAME="salaryProcessor"
DLQ_NAME="ImageProcessingDLQ"
SNS_TOPIC_NAME="SalaryFileUploadTopic"
SQS_QUEUE_NAME="SalaryProcessingQueue"

echo "============================================"
echo " Scaler Analytics - Pipeline Setup"
echo " Account ID : $ACCOUNT_ID"
echo " Region     : $REGION"
echo "============================================"

# ─────────────────────────────────────────────
# 1. CREATE CSV DATA FILES
# ─────────────────────────────────────────────
echo ""
echo "[1/8] Creating salary CSV files..."

mkdir -p "$DATA_DIR"


cat > "$DATA_DIR/Scalersalary_Mar.csv" << 'CSVEOF'
emp_id,name,salary,month,dept_id
1,Amit,53000,Mar,101
2,Riya,62000,Mar,102
2,Riya,6000,Mar,102
3,John,58000,Mar,103
4,Sneha,61000,Mar,101
5,Arjun,65000,Mar,104
6,Meera,55000,Mar,105
7,Rahul,51000,Mar,101
8,Priya,63000,Mar,102
9,Karan,54000,Mar,103
10,Isha,56000,Mar,104
11,Neha,53000,Mar,105
12,Aditya,65000,Mar,101
13,Laura,59000,Mar,102
14,Vikram,67000,Mar,103
15,Pooja,49000,Mar,104
16,Sam,61000,Mar,105
17,Rohit,58000,Mar,101
18,Anita,52000,Mar,102
19,David,60000,Mar,103
CSVEOF

echo "  CSV files created in $DATA_DIR/"

# ─────────────────────────────────────────────
# 2. CREATE S3 BUCKETS
# ─────────────────────────────────────────────
echo ""
echo "[2/8] Creating S3 buckets..."

for BUCKET in "$UPLOAD_BUCKET" "$PROCESSED_BUCKET"; do
  if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
    echo "  Bucket already exists: $BUCKET"
  else
    aws s3api create-bucket \
      --bucket "$BUCKET" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION" \
      --no-cli-pager > /dev/null
    echo "  Created bucket: $BUCKET"
  fi
done

for BUCKET in "$UPLOAD_BUCKET" "$PROCESSED_BUCKET"; do
  aws s3api put-public-access-block \
    --bucket "$BUCKET" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
    > /dev/null
done
echo "  Public access blocked on both buckets"

aws s3api put-object --bucket "$UPLOAD_BUCKET"    --key "input/"  > /dev/null
aws s3api put-object --bucket "$PROCESSED_BUCKET" --key "output/" > /dev/null
echo "  Created input/ and output/ prefixes"

# ─────────────────────────────────────────────
# 3. (SKIPPED) Upload CSV files — upload manually to trigger pipeline
# ─────────────────────────────────────────────
echo ""
echo "[3/8] Skipping CSV upload (upload manually to trigger pipeline)"

# ─────────────────────────────────────────────
# 4. CREATE SNS TOPIC
# ─────────────────────────────────────────────
echo ""
echo "[4/8] Creating SNS topic..."

SNS_ARN=$(aws sns create-topic \
  --name "$SNS_TOPIC_NAME" \
  --region "$REGION" \
  --query TopicArn --output text)

echo "  SNS Topic ARN: $SNS_ARN"

# ─────────────────────────────────────────────
# 5. CREATE SQS QUEUES (DLQ + Main)
# ─────────────────────────────────────────────
echo ""
echo "[5/8] Creating SQS queues..."

DLQ_URL=$(aws sqs create-queue \
  --queue-name "$DLQ_NAME" \
  --region "$REGION" \
  --query QueueUrl --output text)

DLQ_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$DLQ_URL" \
  --attribute-names QueueArn \
  --query Attributes.QueueArn --output text)

echo "  DLQ URL : $DLQ_URL"
echo "  DLQ ARN : $DLQ_ARN"

QUEUE_URL=$(aws sqs create-queue \
  --queue-name "$SQS_QUEUE_NAME" \
  --region "$REGION" \
  --attributes "{
      \"VisibilityTimeout\": \"300\",
      \"MessageRetentionPeriod\": \"86400\",
      \"RedrivePolicy\": \"{\\\"deadLetterTargetArn\\\":\\\"${DLQ_ARN}\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"
    }" \
  --query QueueUrl --output text)

QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attribute-names QueueArn \
  --query Attributes.QueueArn --output text)

echo "  Queue URL : $QUEUE_URL"
echo "  Queue ARN : $QUEUE_ARN"

aws sqs set-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attributes "{
      \"Policy\": \"{\\\"Version\\\":\\\"2012-10-17\\\",\\\"Statement\\\":[{\\\"Effect\\\":\\\"Allow\\\",\\\"Principal\\\":{\\\"Service\\\":\\\"sns.amazonaws.com\\\"},\\\"Action\\\":\\\"sqs:SendMessage\\\",\\\"Resource\\\":\\\"${QUEUE_ARN}\\\",\\\"Condition\\\":{\\\"ArnEquals\\\":{\\\"aws:SourceArn\\\":\\\"${SNS_ARN}\\\"}}}]}\"
    }"
echo "  SQS policy updated to allow SNS messages"

aws sns subscribe \
  --topic-arn "$SNS_ARN" \
  --protocol sqs \
  --notification-endpoint "$QUEUE_ARN" \
  --region "$REGION" > /dev/null
echo "  SQS subscribed to SNS topic"

# ─────────────────────────────────────────────
# 6. CREATE LAMBDA EXECUTION ROLE
# ─────────────────────────────────────────────
echo ""
echo "[6/8] Creating Lambda IAM role..."

ROLE_NAME="salaryProcessorLambdaRole"

TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}'

ROLE_ARN=$(aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY" \
  --query Role.Arn --output text 2>/dev/null \
  || aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text)

echo "  Role ARN: $ROLE_ARN"

aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "SalaryProcessorS3Access" \
  --policy-document "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [
        {
          \"Effect\": \"Allow\",
          \"Action\": [\"s3:GetObject\", \"s3:ListBucket\"],
          \"Resource\": [
            \"arn:aws:s3:::${UPLOAD_BUCKET}\",
            \"arn:aws:s3:::${UPLOAD_BUCKET}/*\"
          ]
        },
        {
          \"Effect\": \"Allow\",
          \"Action\": [\"s3:PutObject\"],
          \"Resource\": [
            \"arn:aws:s3:::${PROCESSED_BUCKET}\",
            \"arn:aws:s3:::${PROCESSED_BUCKET}/*\"
          ]
        }
      ]
    }"

echo "  IAM policies attached"
echo "  Waiting 5s for IAM role propagation..."
sleep 5

# ─────────────────────────────────────────────
# 7. CREATE LAMBDA FUNCTION (token placeholder)
# ─────────────────────────────────────────────
echo ""
echo "[7/8] Creating Lambda function (token placeholder)..."

mkdir -p /tmp/lambda_pkg

cat > /tmp/lambda_pkg/lambda_function.py << 'PYEOF'
import json

def lambda_handler(event, context):
    """
    salaryProcessor - Token Placeholder Lambda
    TODO: Implement salary aggregation logic

    Expected flow:
      1. Triggered by SQS (which receives S3 event via SNS)
      2. Download CSV from s3://<UPLOAD_BUCKET>/input/
      3. Aggregate salary by dept_id and month (SUM)
      4. Write output to s3://<PROCESSED_BUCKET>/output/deptMonthAggSalary<ACCOUNT_ID>.csv
    """
    print("Event received:", json.dumps(event))
    return {"statusCode": 200, "body": "Placeholder - implement me!"}
PYEOF

cd /tmp/lambda_pkg && zip -q lambda.zip lambda_function.py && cd -

if aws lambda get-function --function-name "$LAMBDA_NAME" --region "$REGION" 2>/dev/null; then
  aws lambda update-function-code \
    --function-name "$LAMBDA_NAME" \
    --zip-file fileb:///tmp/lambda_pkg/lambda.zip \
    --region "$REGION" > /dev/null
  echo "  Lambda updated: $LAMBDA_NAME"
else
  aws lambda create-function \
    --function-name "$LAMBDA_NAME" \
    --runtime python3.12 \
    --role "$ROLE_ARN" \
    --handler lambda_function.lambda_handler \
    --zip-file fileb:///tmp/lambda_pkg/lambda.zip \
    --timeout 300 \
    --memory-size 512 \
    --environment "Variables={UPLOAD_BUCKET=${UPLOAD_BUCKET},PROCESSED_BUCKET=${PROCESSED_BUCKET},ACCOUNT_ID=${ACCOUNT_ID}}" \
    --region "$REGION" > /dev/null
  echo "  Lambda created: $LAMBDA_NAME"
fi

echo "  Waiting for Lambda to become active..."
aws lambda wait function-active --function-name "$LAMBDA_NAME" --region "$REGION"
echo "  Lambda is active"

EXISTING_UUID=$(aws lambda list-event-source-mappings \
  --function-name "$LAMBDA_NAME" \
  --event-source-arn "$QUEUE_ARN" \
  --region "$REGION" \
  --query 'EventSourceMappings[0].UUID' \
  --output text 2>/dev/null || echo "")

if [ "$EXISTING_UUID" = "None" ] || [ -z "$EXISTING_UUID" ]; then
  aws lambda create-event-source-mapping \
    --function-name "$LAMBDA_NAME" \
    --event-source-arn "$QUEUE_ARN" \
    --batch-size 1 \
    --region "$REGION" > /dev/null
  echo "  SQS event source mapping created"
else
  echo "  SQS event source mapping already exists (UUID: $EXISTING_UUID)"
fi

# ─────────────────────────────────────────────
# 8. CONFIGURE S3 -> SNS NOTIFICATION
# ─────────────────────────────────────────────
echo ""
echo "[8/8] Configuring S3 -> SNS event notification..."

aws sns set-topic-attributes \
  --topic-arn "$SNS_ARN" \
  --attribute-name Policy \
  --attribute-value "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [{
        \"Effect\": \"Allow\",
        \"Principal\": { \"Service\": \"s3.amazonaws.com\" },
        \"Action\": \"SNS:Publish\",
        \"Resource\": \"${SNS_ARN}\",
        \"Condition\": {
          \"ArnLike\": { \"aws:SourceArn\": \"arn:aws:s3:::${UPLOAD_BUCKET}\" }
        }
      }]
    }"
echo "  SNS topic policy updated to allow S3 publish"

aws s3api put-bucket-notification-configuration \
  --bucket "$UPLOAD_BUCKET" \
  --notification-configuration "{
      \"TopicConfigurations\": [{
        \"Id\": \"SalaryFileUploadTrigger\",
        \"TopicArn\": \"${SNS_ARN}\",
        \"Events\": [\"s3:ObjectCreated:*\"],
        \"Filter\": {
          \"Key\": {
            \"FilterRules\": [
              { \"Name\": \"prefix\", \"Value\": \"input/\" },
              { \"Name\": \"suffix\", \"Value\": \".csv\" }
            ]
          }
        }
      }]
    }"
echo "  S3 event notification configured (input/*.csv -> SNS)"

chown user:user -R "$TARGET_DIR"

# ─────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "  Resources created:"
echo "    S3 Upload Bucket   : s3://${UPLOAD_BUCKET}/input/"
echo "    S3 Output Bucket   : s3://${PROCESSED_BUCKET}/output/"
echo "    SNS Topic          : $SNS_ARN"
echo "    SQS Queue          : $QUEUE_URL"
echo "    SQS DLQ            : $DLQ_URL"
echo "    Lambda Function    : $LAMBDA_NAME  (token placeholder)"
echo "    Lambda Role        : $ROLE_ARN"
echo ""
echo "  Data flow:"
echo "    CSV upload -> S3 -> SNS -> SQS -> Lambda -> Aggregated CSV in processed bucket"
echo ""
echo "  CSV files ready to upload:"
echo "    s3://${UPLOAD_BUCKET}/input/Scalersalary_Mar.csv"
echo ""
echo "  Expected output:"
echo "    s3://${PROCESSED_BUCKET}/output/deptMonthAggSalary${ACCOUNT_ID}.csv"
echo ""
echo "  Next step: implement lambda_function.py with aggregation logic"
echo "============================================"
EOF

# Set permissions
sudo chmod 771 "$TARGET_FILE"
chown user:user "$TARGET_FILE"

echo "Pipeline script created at $TARGET_FILE with permissions 771"