#!/bin/bash
set -euo pipefail

export AWS_PAGER=""

LAB_DIR="/home/user/vitalroute-lab"
REGION="us-west-2"

echo "Installing zip and jq..."
apt update
apt-get install -y zip jq > /dev/null 2>&1 || yum install -y zip jq > /dev/null 2>&1

mkdir -p "$LAB_DIR"

cat > "$LAB_DIR/lambda_function.py" << 'PYEOF'
import json
import os

RAW_DATA = {
    "driver_id": "DRV-9921",
    "name": "Ravi Shankar",
    "phone": "9876543210",
    "bank_account": "HDFC-00291837",
    "route": "Koramangala-BTM",
    "status": "active"
}

MASKED_DATA = {
    "driver_id": "DRV-9921",
    "name": "R*** S******",
    "phone": "98*****210",
    "bank_account": "HDFC-XXXXXX37",
    "route": "Koramangala-BTM",
    "status": "active"
}

def lambda_handler(event, context):
    env = os.environ.get("APP_ENV", "dev")

    if env == "prod":
        payload = MASKED_DATA
    else:
        payload = RAW_DATA

    return {
        "statusCode": 200,
        "body": json.dumps({
            "env": env,
            "data": payload
        })
    }
PYEOF

chown -R user:user "$LAB_DIR"

echo ""
echo "========================================="
echo "  VitalRoute Lab Environment Ready"
echo "========================================="
echo ""
echo "Lab directory : $LAB_DIR"
echo ""
echo "Available files:"
echo "  lambda_function.py   -- Application code to deploy to your Lambda"
echo ""
echo "Getting started:"
echo "  1. Create your IAM role and Lambda function first"
echo "  2. Once your Lambda function is created, package and deploy the code:"
echo ""
echo "     cd /home/user/vitalroute-lab"
echo "     zip -j function.zip lambda_function.py"
echo "     aws lambda update-function-code \\"
echo "       --function-name vitalroute-delivery-fn \\"
echo "       --zip-file fileb://function.zip \\"
echo "       --region us-west-2"
echo ""
echo "  3. Invoke the function to observe the current (dev) response:"
echo ""
echo "     aws lambda invoke \\"
echo "       --function-name vitalroute-delivery-fn \\"
echo "       --region us-west-2 \\"
echo "       --payload '{}' \\"
echo "       --cli-binary-format raw-in-base64-out \\"
echo "       response.json && cat response.json"
echo ""
echo "  4. Fix the APP_ENV variable, invoke again, and verify the response is masked."
echo ""