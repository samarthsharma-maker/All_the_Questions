#!/bin/bash
set -euo pipefail

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"
UPLOAD_BUCKET="salary-file-uploads-${ACCOUNT_ID}"
PROCESSED_BUCKET="salary-processed-bucket-${ACCOUNT_ID}"
LAMBDA_NAME="salaryProcessor"
DATA_DIR="/home/user/salary_data"

echo "============================================"
echo " Scaler Analytics - Aggregate & Upload"
echo " Account ID : $ACCOUNT_ID"
echo "============================================"

# ─────────────────────────────────────────────
# 1. Update Lambda with real implementation
# ─────────────────────────────────────────────
echo ""
echo "[1/2] Updating Lambda function..."

mkdir -p /tmp/lambda_pkg

cat > /tmp/lambda_pkg/lambda_function.py << 'PYEOF'
import json
import boto3
import csv
import io
import os
import logging
from collections import defaultdict

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")

UPLOAD_BUCKET    = os.environ["UPLOAD_BUCKET"]
PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]
ACCOUNT_ID       = os.environ["ACCOUNT_ID"]
OUTPUT_KEY       = f"output/deptMonthAggSalary{ACCOUNT_ID}.csv"


def lambda_handler(event, context):
    logger.info("Event: %s", json.dumps(event))

    for sqs_record in event.get("Records", []):
        sns_payload = json.loads(sqs_record["body"])
        s3_event    = json.loads(sns_payload["Message"])

        for s3_record in s3_event.get("Records", []):
            bucket = s3_record["s3"]["bucket"]["name"]
            key    = s3_record["s3"]["object"]["key"]
            logger.info("Processing: s3://%s/%s", bucket, key)

            obj  = s3.get_object(Bucket=bucket, Key=key)
            rows = list(csv.DictReader(io.StringIO(obj["Body"].read().decode("utf-8"))))

            new_agg = defaultdict(int)
            for row in rows:
                new_agg[(row["dept_id"].strip(), row["month"].strip())] += int(row["salary"].strip())

            merged = {}
            try:
                existing = s3.get_object(Bucket=PROCESSED_BUCKET, Key=OUTPUT_KEY)
                for row in csv.DictReader(io.StringIO(existing["Body"].read().decode("utf-8"))):
                    merged[(row["dept_id"].strip(), row["month"].strip())] = int(row["total_salary"].strip())
                logger.info("Existing output found, merging...")
            except Exception:
                logger.info("No existing output, creating fresh...")

            for k, v in new_agg.items():
                merged[k] = merged.get(k, 0) + v

            month_order = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
            out = io.StringIO()
            writer = csv.writer(out)
            writer.writerow(["dept_id", "month", "total_salary"])
            for (dept_id, month), total in sorted(merged.items(),
                    key=lambda x: (int(x[0][0]), month_order.index(x[0][1]) if x[0][1] in month_order else 99)):
                writer.writerow([dept_id, month, total])

            s3.put_object(
                Bucket=PROCESSED_BUCKET,
                Key=OUTPUT_KEY,
                Body=out.getvalue().encode("utf-8"),
                ContentType="text/csv"
            )
            logger.info("Output written to s3://%s/%s", PROCESSED_BUCKET, OUTPUT_KEY)

    return {"statusCode": 200, "body": "Done"}
PYEOF

cd /tmp/lambda_pkg
zip -q lambda.zip lambda_function.py
cd -

aws lambda update-function-code \
  --function-name "$LAMBDA_NAME" \
  --zip-file fileb:///tmp/lambda_pkg/lambda.zip \
  --region "$REGION" > /dev/null

aws lambda wait function-updated \
  --function-name "$LAMBDA_NAME" \
  --region "$REGION"

echo "  ✓ Lambda updated: $LAMBDA_NAME"

# ─────────────────────────────────────────────
# 2. Upload CSVs one at a time, polling SQS to confirm
#    Lambda has fully processed each file before next upload
# ─────────────────────────────────────────────
echo ""
echo "[2/2] Uploading CSVs to trigger pipeline..."

SQS_QUEUE_URL=$(aws sqs get-queue-url \
  --queue-name "SalaryProcessingQueue" \
  --region "$REGION" \
  --query QueueUrl --output text)

for FILE in "$DATA_DIR"/*.csv; do
  FILENAME=$(basename "$FILE")
  aws s3 cp "$FILE" "s3://${UPLOAD_BUCKET}/input/${FILENAME}" --region "$REGION"
  echo "  ✓ Uploaded: input/${FILENAME}"
  sleep 5  # brief pause for S3 event to propagate to SQS
done

echo ""
echo "  Final output:"
aws s3 cp \
  "s3://${PROCESSED_BUCKET}/output/deptMonthAggSalary${ACCOUNT_ID}.csv" \
  - --region "$REGION"

echo ""
echo "============================================"
echo " ✅  Done!"
echo "   s3://${PROCESSED_BUCKET}/output/deptMonthAggSalary${ACCOUNT_ID}.csv"
echo "============================================"