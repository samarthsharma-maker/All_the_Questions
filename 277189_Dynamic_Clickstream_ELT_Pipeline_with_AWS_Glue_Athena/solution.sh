#!/bin/bash
set -e  # Exit on any error
set -u  # Exit on undefined variables

# ============================================================================
# AWS Glue Clickstream Pipeline - Complete Working Solution
# ============================================================================
# This script implements an event-driven clickstream analytics pipeline using:
# - Amazon S3 for storage
# - AWS Glue for cataloging and ETL
# - Amazon Athena for queries
# ============================================================================

echo "========================================="
echo "Starting Clickstream Pipeline Setup"
echo "========================================="

# Configuration
export REGION="${REGION:-us-west-2}"
export ACCOUNT_ID="${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text --no-cli-pager)}"
export RAW_BUCKET="${RAW_BUCKET:-clickstream-raw-${ACCOUNT_ID}}"
export PROCESSED_BUCKET="${PROCESSED_BUCKET:-clickstream-processed-${ACCOUNT_ID}}"
export ATHENA_RESULTS_BUCKET="${ATHENA_RESULTS_BUCKET:-athena-results-${ACCOUNT_ID}}"
export DATABASE_NAME="${DATABASE_NAME:-clickstream_db}"
export CRAWLER_NAME="${CRAWLER_NAME:-raw-clickstream-crawler}"
export ROLE_NAME="${ROLE_NAME:-GlueETLServiceRole}"
export ETL_JOB_NAME="${ETL_JOB_NAME:-transform-clickstream-timestamps}"

# Validate required variables
if [ -z "$REGION" ]; then
    echo "ERROR: REGION is not set"
    exit 1
fi

if [ -z "$ACCOUNT_ID" ]; then
    echo "ERROR: Could not determine AWS Account ID"
    exit 1
fi

echo "Account ID: ${ACCOUNT_ID}"
echo "Region: ${REGION}"
echo ""

# ============================================================================
# STEP 1: Create S3 Buckets
# ============================================================================
echo "Step 1: Creating S3 Buckets..."

if aws s3 ls "s3://${RAW_BUCKET}" --region "${REGION}" --no-cli-pager 2>/dev/null; then
    echo "  ✓ Raw bucket already exists: ${RAW_BUCKET}"
else
    aws s3 mb "s3://${RAW_BUCKET}" --region "${REGION}" --no-cli-pager
    echo "  ✓ Created raw bucket: ${RAW_BUCKET}"
fi

if aws s3 ls "s3://${PROCESSED_BUCKET}" --region "${REGION}" --no-cli-pager 2>/dev/null; then
    echo "  ✓ Processed bucket already exists: ${PROCESSED_BUCKET}"
else
    aws s3 mb "s3://${PROCESSED_BUCKET}" --region "${REGION}" --no-cli-pager
    echo "  ✓ Created processed bucket: ${PROCESSED_BUCKET}"
fi

if aws s3 ls "s3://${ATHENA_RESULTS_BUCKET}" --region "${REGION}" --no-cli-pager 2>/dev/null; then
    echo "  ✓ Athena results bucket already exists: ${ATHENA_RESULTS_BUCKET}"
else
    aws s3 mb "s3://${ATHENA_RESULTS_BUCKET}" --region "${REGION}" --no-cli-pager
    echo "  ✓ Created Athena results bucket: ${ATHENA_RESULTS_BUCKET}"
fi

echo ""

# ============================================================================
# STEP 2: Create IAM Role for Glue
# ============================================================================
echo "Step 2: Setting up IAM Role..."

cat > /tmp/glue-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "glue.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

if aws iam get-role --role-name "${ROLE_NAME}" --no-cli-pager 2>/dev/null >/dev/null; then
    echo "  ✓ Role already exists: ${ROLE_NAME}"
else
    aws iam create-role \
        --role-name "${ROLE_NAME}" \
        --assume-role-policy-document file:///tmp/glue-trust-policy.json \
        --output json \
        --no-cli-pager > /dev/null
    echo "  ✓ Created role: ${ROLE_NAME}"
fi

# Attach policies
aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole \
    --no-cli-pager 2>/dev/null || echo "  - AWSGlueServiceRole already attached"

aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess \
    --no-cli-pager 2>/dev/null || echo "  - AmazonS3FullAccess already attached"

echo "  ✓ IAM Role configured"
echo ""

# Wait for role to propagate
echo "  Waiting 10 seconds for IAM role to propagate..."
sleep 10

# ============================================================================
# STEP 3: Prepare Initial Sample Data (Version 1)
# ============================================================================
echo "Step 3: Preparing initial sample data..."

mkdir -p ./clickstream_sample/year=2025/month=06/day=20/hour=14

cat > ./clickstream_sample/year=2025/month=06/day=20/hour=14/data.csv <<'EOF'
user_id,event_time,event_type,page_url
u123,2025-06-20T14:01:05Z,view,/home
u456,2025-06-20T14:02:30Z,click,/product/42
u123,2025-06-20T14:05:12Z,view,/cart
u789,2025-06-20T14:10:45Z,click,/product/99
u456,2025-06-20T14:15:20Z,view,/checkout
EOF

echo "  ✓ Created initial data with 4 columns"

# Upload initial data
aws s3 cp --recursive ./clickstream_sample "s3://${RAW_BUCKET}/" --region "${REGION}" --quiet --no-cli-pager
echo "  ✓ Uploaded initial data to S3"
echo ""

# ============================================================================
# STEP 4: Create Glue Database
# ============================================================================
echo "Step 4: Creating Glue Database..."

if aws glue get-database --name "${DATABASE_NAME}" --region "${REGION}" --no-cli-pager 2>/dev/null >/dev/null; then
    echo "  ✓ Database already exists: ${DATABASE_NAME}"
else
    aws glue create-database \
        --database-input '{"Name":"'"${DATABASE_NAME}"'","Description":"Clickstream analytics database"}' \
        --region "${REGION}" \
        --output json \
        --no-cli-pager > /dev/null
    echo "  ✓ Created database: ${DATABASE_NAME}"
fi

echo ""

# ============================================================================
# STEP 5: Create CSV Classifier
# ============================================================================
echo "Step 5: Creating CSV Classifier..."

if aws glue get-classifier --name csv-classifier-with-headers --region "${REGION}" --no-cli-pager 2>/dev/null >/dev/null; then
    echo "  ✓ Classifier already exists"
else
    aws glue create-classifier --csv-classifier '{
        "Name": "csv-classifier-with-headers",
        "Delimiter": ",",
        "QuoteSymbol": "\"",
        "ContainsHeader": "PRESENT",
        "AllowSingleColumn": false
    }' --region "${REGION}" --output json --no-cli-pager > /dev/null
    echo "  ✓ Created CSV classifier"
fi

echo ""

# ============================================================================
# STEP 6: Create and Configure Glue Crawler
# ============================================================================
echo "Step 6: Creating Glue Crawler..."

if aws glue get-crawler --name "${CRAWLER_NAME}" --region "${REGION}" --no-cli-pager 2>/dev/null >/dev/null; then
    echo "  ✓ Crawler already exists: ${CRAWLER_NAME}"
else
    aws glue create-crawler \
        --name "${CRAWLER_NAME}" \
        --role "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" \
        --database-name "${DATABASE_NAME}" \
        --targets '{"S3Targets":[{"Path":"s3://'"${RAW_BUCKET}"'/"}]}' \
        --classifiers '["csv-classifier-with-headers"]' \
        --schema-change-policy '{"UpdateBehavior":"UPDATE_IN_DATABASE","DeleteBehavior":"LOG"}' \
        --recrawl-policy '{"RecrawlBehavior":"CRAWL_EVERYTHING"}' \
        --region "${REGION}" \
        --output json \
        --no-cli-pager > /dev/null
    echo "  ✓ Created crawler: ${CRAWLER_NAME}"
fi

echo ""

# ============================================================================
# STEP 7: Run Initial Crawler to Catalog Data
# ============================================================================
echo "Step 7: Running initial crawler..."

# Start the crawler
aws glue start-crawler --name "${CRAWLER_NAME}" --region "${REGION}" --output json --no-cli-pager > /dev/null
echo "  ✓ Started crawler"

# Wait for crawler to complete
echo "  Waiting for crawler to complete..."
WAIT_COUNT=0
MAX_WAIT=120  # 10 minutes max
while true; do
    STATE=$(aws glue get-crawler --name "${CRAWLER_NAME}" --region "${REGION}" --query 'Crawler.State' --output text --no-cli-pager 2>/dev/null || echo "ERROR")
    
    if [ "$STATE" == "READY" ]; then
        echo "  ✓ Crawler completed successfully"
        break
    elif [ "$STATE" == "STOPPING" ] || [ "$STATE" == "RUNNING" ]; then
        echo "    Status: $STATE (waiting...)"
        sleep 5
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -gt $MAX_WAIT ]; then
            echo "  ✗ Timeout waiting for crawler"
            exit 1
        fi
    else
        echo "  ✗ Unexpected crawler state: $STATE"
        exit 1
    fi
done

echo ""

# ============================================================================
# STEP 8: Verify Initial Table Schema
# ============================================================================
echo "Step 8: Verifying initial table schema..."

sleep 3  # Brief pause to ensure table is available

TABLE_NAME=$(aws glue get-tables --database-name "${DATABASE_NAME}" --region "${REGION}" --query 'TableList[0].Name' --output text --no-cli-pager 2>/dev/null || echo "")

if [ -z "$TABLE_NAME" ] || [ "$TABLE_NAME" == "None" ]; then
    echo "  ✗ ERROR: No table was created by the crawler"
    echo "  Checking what tables exist..."
    aws glue get-tables --database-name "${DATABASE_NAME}" --region "${REGION}" --no-cli-pager
    exit 1
fi

echo "  Detected table name: ${TABLE_NAME}"

echo "  Initial schema columns:"
aws glue get-table \
    --database-name "${DATABASE_NAME}" \
    --name "${TABLE_NAME}" \
    --region "${REGION}" \
    --query 'Table.StorageDescriptor.Columns[*].[Name,Type]' \
    --output text \
    --no-cli-pager | awk '{printf "    %-20s %s\n", $1, $2}'

echo ""

# ============================================================================
# STEP 9: Add New Data with Additional Column (Schema Evolution)
# ============================================================================
echo "Step 9: Preparing data with schema evolution (adding session_duration)..."

mkdir -p ./clickstream_sample/year=2025/month=06/day=20/hour=15

cat > ./clickstream_sample/year=2025/month=06/day=20/hour=15/data_v2.csv <<'EOF'
user_id,event_time,event_type,page_url,session_duration
u789,2025-06-20T15:07:00Z,click,/checkout,45
u999,2025-06-20T15:10:00Z,view,/success,10
u123,2025-06-20T15:15:30Z,click,/product/55,120
u456,2025-06-20T15:20:15Z,view,/cart,60
EOF

echo "  ✓ Created data with 5 columns (new: session_duration)"

# Upload new data
aws s3 cp --recursive ./clickstream_sample "s3://${RAW_BUCKET}/" --region "${REGION}" --quiet --no-cli-pager
echo "  ✓ Uploaded new data to S3"
echo ""

# ============================================================================
# STEP 10: Re-run Crawler to Detect Schema Changes
# ============================================================================
echo "Step 10: Re-running crawler to detect schema changes..."

aws glue start-crawler --name "${CRAWLER_NAME}" --region "${REGION}" --output json --no-cli-pager > /dev/null
echo "  ✓ Started crawler for schema evolution"

echo "  Waiting for crawler to complete..."
WAIT_COUNT=0
while true; do
    STATE=$(aws glue get-crawler --name "${CRAWLER_NAME}" --region "${REGION}" --query 'Crawler.State' --output text --no-cli-pager 2>/dev/null || echo "ERROR")
    
    if [ "$STATE" == "READY" ]; then
        echo "  ✓ Crawler completed successfully"
        break
    elif [ "$STATE" == "STOPPING" ] || [ "$STATE" == "RUNNING" ]; then
        echo "    Status: $STATE (waiting...)"
        sleep 5
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -gt $MAX_WAIT ]; then
            echo "  ✗ Timeout waiting for crawler"
            exit 1
        fi
    else
        echo "  ✗ Unexpected crawler state: $STATE"
        exit 1
    fi
done

echo ""

# ============================================================================
# STEP 11: Verify Updated Schema
# ============================================================================
echo "Step 11: Verifying updated schema..."

sleep 3

echo "  Updated schema columns (should include session_duration):"
aws glue get-table \
    --database-name "${DATABASE_NAME}" \
    --name "${TABLE_NAME}" \
    --region "${REGION}" \
    --query 'Table.StorageDescriptor.Columns[*].[Name,Type]' \
    --output text \
    --no-cli-pager | awk '{printf "    %-20s %s\n", $1, $2}'

echo ""

# ============================================================================
# STEP 12: Create Glue ETL Job (PySpark Script)
# ============================================================================
echo "Step 12: Creating Glue ETL Job..."

# Create PySpark script for timestamp transformation with CORRECT imports
cat > /tmp/glue_etl_script.py <<'PYTHON_SCRIPT'
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame
from pyspark.sql.functions import to_timestamp

# Initialize Glue context
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'DATABASE_NAME', 'TABLE_NAME', 'OUTPUT_BUCKET'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Read from Glue Data Catalog
datasource = glueContext.create_dynamic_frame.from_catalog(
    database=args['DATABASE_NAME'],
    table_name=args['TABLE_NAME'],
    transformation_ctx="datasource"
)

# Convert to Spark DataFrame for transformation
df = datasource.toDF()

# Transform event_time string to timestamp
df_transformed = df.withColumn(
    "event_timestamp",
    to_timestamp("event_time", "yyyy-MM-dd'T'HH:mm:ss'Z'")
).drop("event_time")

# Convert back to DynamicFrame
dynamic_frame = DynamicFrame.fromDF(df_transformed, glueContext, "dynamic_frame")

# Write to S3 as Parquet with partitioning
glueContext.write_dynamic_frame.from_options(
    frame=dynamic_frame,
    connection_type="s3",
    connection_options={
        "path": f"s3://{args['OUTPUT_BUCKET']}/clickstream_processed/",
        "partitionKeys": ["year", "month", "day", "hour"]
    },
    format="parquet",
    format_options={
        "compression": "snappy"
    },
    transformation_ctx="datasink"
)

job.commit()
PYTHON_SCRIPT

# Upload script to S3
SCRIPT_LOCATION="s3://${PROCESSED_BUCKET}/scripts/glue_etl_script.py"
aws s3 cp /tmp/glue_etl_script.py "${SCRIPT_LOCATION}" --region "${REGION}" --quiet --no-cli-pager
echo "  ✓ Uploaded ETL script to: ${SCRIPT_LOCATION}"

# Create the Glue ETL Job
if aws glue get-job --job-name "${ETL_JOB_NAME}" --region "${REGION}" --no-cli-pager 2>/dev/null >/dev/null; then
    echo "  ✓ ETL Job already exists: ${ETL_JOB_NAME}"
    echo "  Updating job with latest script..."
    
    aws glue update-job \
        --job-name "${ETL_JOB_NAME}" \
        --job-update '{
            "Role": "arn:aws:iam::'"${ACCOUNT_ID}"':role/'"${ROLE_NAME}"'",
            "Command": {
                "Name": "glueetl",
                "ScriptLocation": "'"${SCRIPT_LOCATION}"'",
                "PythonVersion": "3"
            },
            "DefaultArguments": {
                "--job-language": "python",
                "--DATABASE_NAME": "'"${DATABASE_NAME}"'",
                "--TABLE_NAME": "'"${TABLE_NAME}"'",
                "--OUTPUT_BUCKET": "'"${PROCESSED_BUCKET}"'",
                "--enable-metrics": "true",
                "--enable-continuous-cloudwatch-log": "true"
            },
            "MaxRetries": 0,
            "Timeout": 2880,
            "GlueVersion": "4.0",
            "NumberOfWorkers": 2,
            "WorkerType": "G.1X"
        }' \
        --region "${REGION}" \
        --output json \
        --no-cli-pager > /dev/null
    echo "  ✓ Job updated"
else
    aws glue create-job \
        --name "${ETL_JOB_NAME}" \
        --role "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" \
        --command '{
            "Name": "glueetl",
            "ScriptLocation": "'"${SCRIPT_LOCATION}"'",
            "PythonVersion": "3"
        }' \
        --default-arguments '{
            "--job-language": "python",
            "--DATABASE_NAME": "'"${DATABASE_NAME}"'",
            "--TABLE_NAME": "'"${TABLE_NAME}"'",
            "--OUTPUT_BUCKET": "'"${PROCESSED_BUCKET}"'",
            "--enable-metrics": "true",
            "--enable-continuous-cloudwatch-log": "true"
        }' \
        --max-retries 0 \
        --timeout 2880 \
        --glue-version "4.0" \
        --number-of-workers 2 \
        --worker-type "G.1X" \
        --region "${REGION}" \
        --output json \
        --no-cli-pager > /dev/null
    echo "  ✓ Created ETL Job: ${ETL_JOB_NAME}"
fi

echo ""

# ============================================================================
# STEP 13: Run Glue ETL Job
# ============================================================================
echo "Step 13: Running Glue ETL Job..."

JOB_RUN_ID=$(aws glue start-job-run \
    --job-name "${ETL_JOB_NAME}" \
    --region "${REGION}" \
    --query 'JobRunId' \
    --output text \
    --no-cli-pager)

echo "  ✓ Started job run: ${JOB_RUN_ID}"
echo "  Waiting for job to complete (this may take 3-5 minutes)..."

WAIT_COUNT=0
MAX_JOB_WAIT=60  # 15 minutes max
while true; do
    JOB_STATUS=$(aws glue get-job-run \
        --job-name "${ETL_JOB_NAME}" \
        --run-id "${JOB_RUN_ID}" \
        --region "${REGION}" \
        --query 'JobRun.JobRunState' \
        --output text \
        --no-cli-pager 2>/dev/null || echo "ERROR")
    
    if [ "$JOB_STATUS" == "SUCCEEDED" ]; then
        echo "  ✓ ETL Job completed successfully!"
        
        # Get job execution time
        EXECUTION_TIME=$(aws glue get-job-run \
            --job-name "${ETL_JOB_NAME}" \
            --run-id "${JOB_RUN_ID}" \
            --region "${REGION}" \
            --query 'JobRun.ExecutionTime' \
            --output text \
            --no-cli-pager 2>/dev/null || echo "N/A")
        echo "  Execution time: ${EXECUTION_TIME} seconds"
        break
    elif [ "$JOB_STATUS" == "RUNNING" ]; then
        echo "    Status: RUNNING (waiting...)"
        sleep 15
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -gt $MAX_JOB_WAIT ]; then
            echo "  ✗ Timeout waiting for job"
            exit 1
        fi
    elif [ "$JOB_STATUS" == "FAILED" ] || [ "$JOB_STATUS" == "STOPPED" ]; then
        echo "  ✗ Job failed with status: $JOB_STATUS"
        echo ""
        echo "  Error details:"
        aws glue get-job-run \
            --job-name "${ETL_JOB_NAME}" \
            --run-id "${JOB_RUN_ID}" \
            --region "${REGION}" \
            --query 'JobRun.ErrorMessage' \
            --output text \
            --no-cli-pager
        echo ""
        echo "  Check CloudWatch logs at:"
        echo "  https://console.aws.amazon.com/cloudwatch/home?region=${REGION}#logsV2:log-groups/log-group/\$252Faws-glue\$252Fjobs\$252Foutput"
        exit 1
    else
        echo "    Status: $JOB_STATUS (waiting...)"
        sleep 15
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -gt $MAX_JOB_WAIT ]; then
            echo "  ✗ Timeout waiting for job"
            exit 1
        fi
    fi
done

echo ""

# ============================================================================
# STEP 14: Update Data Catalog for Processed Table
# ============================================================================
echo "Step 14: Running crawler on processed data..."

# Create crawler for processed data if it doesn't exist
PROCESSED_CRAWLER_NAME="processed-clickstream-crawler"

if aws glue get-crawler --name "${PROCESSED_CRAWLER_NAME}" --region "${REGION}" --no-cli-pager 2>/dev/null >/dev/null; then
    echo "  ✓ Processed crawler already exists"
else
    aws glue create-crawler \
        --name "${PROCESSED_CRAWLER_NAME}" \
        --role "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}" \
        --database-name "${DATABASE_NAME}" \
        --targets '{"S3Targets":[{"Path":"s3://'"${PROCESSED_BUCKET}"'/clickstream_processed/"}]}' \
        --region "${REGION}" \
        --output json \
        --no-cli-pager > /dev/null
    echo "  ✓ Created processed data crawler"
fi

# Run crawler
aws glue start-crawler --name "${PROCESSED_CRAWLER_NAME}" --region "${REGION}" --output json --no-cli-pager > /dev/null
echo "  ✓ Started crawler for processed data"

echo "  Waiting for crawler to complete..."
WAIT_COUNT=0
while true; do
    STATE=$(aws glue get-crawler --name "${PROCESSED_CRAWLER_NAME}" --region "${REGION}" --query 'Crawler.State' --output text --no-cli-pager 2>/dev/null || echo "ERROR")
    
    if [ "$STATE" == "READY" ] || [ "$STATE" == "WAITING" ]; then
        echo "  ✓ Crawler completed"
        break
    elif [ "$STATE" == "STOPPING" ] || [ "$STATE" == "RUNNING" ]; then
        echo "    Status: $STATE (waiting...)"
        sleep 5
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -gt $MAX_WAIT ]; then
            echo "  ✗ Timeout waiting for crawler"
            exit 1
        fi
    fi
done

echo ""

# ============================================================================
# STEP 15: Verify Processed Table Schema
# ============================================================================
echo "Step 15: Verifying processed table schema..."

sleep 3

PROCESSED_TABLE_NAME=$(aws glue get-tables \
    --database-name "${DATABASE_NAME}" \
    --region "${REGION}" \
    --query 'TableList[?starts_with(Name, `clickstream_processed`)].Name | [0]' \
    --output text \
    --no-cli-pager 2>/dev/null || echo "")

if [ -z "$PROCESSED_TABLE_NAME" ] || [ "$PROCESSED_TABLE_NAME" == "None" ]; then
    echo "  ✗ ERROR: Processed table not found"
    echo "  Available tables:"
    aws glue get-tables --database-name "${DATABASE_NAME}" --region "${REGION}" --query 'TableList[*].Name' --no-cli-pager
    exit 1
fi

echo "  Processed table name: ${PROCESSED_TABLE_NAME}"
echo "  Processed table schema (should have event_timestamp as timestamp):"

aws glue get-table \
    --database-name "${DATABASE_NAME}" \
    --name "${PROCESSED_TABLE_NAME}" \
    --region "${REGION}" \
    --query 'Table.StorageDescriptor.Columns[*].[Name,Type]' \
    --output text \
    --no-cli-pager | awk '{printf "    %-20s %s\n", $1, $2}'

echo ""

# ============================================================================
# STEP 16: Query Data with Amazon Athena
# ============================================================================
echo "Step 16: Running Athena queries..."

# Function to run Athena query and wait for completion
run_athena_query() {
    local QUERY="$1"
    local DESCRIPTION="$2"
    
    echo "  Running: $DESCRIPTION"
    
    QUERY_ID=$(aws athena start-query-execution \
        --query-string "$QUERY" \
        --query-execution-context "Database=${DATABASE_NAME}" \
        --result-configuration "OutputLocation=s3://${ATHENA_RESULTS_BUCKET}/" \
        --region "${REGION}" \
        --query 'QueryExecutionId' \
        --output text \
        --no-cli-pager)
    
    # Wait for query completion
    local WAIT_COUNT=0
    while true; do
        STATUS=$(aws athena get-query-execution \
            --query-execution-id "${QUERY_ID}" \
            --region "${REGION}" \
            --query 'QueryExecution.Status.State' \
            --output text \
            --no-cli-pager 2>/dev/null || echo "ERROR")
        
        if [ "$STATUS" == "SUCCEEDED" ]; then
            break
        elif [ "$STATUS" == "FAILED" ] || [ "$STATUS" == "CANCELLED" ]; then
            echo "    ✗ Query failed: $STATUS"
            return 1
        fi
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -gt 30 ]; then
            echo "    ✗ Query timeout"
            return 1
        fi
    done
    
    echo "    ✓ Query completed"
    return 0
}

# Preview processed data
echo ""
echo "Preview of processed data:"
PREVIEW_QUERY_ID=$(aws athena start-query-execution \
    --query-string "SELECT * FROM ${DATABASE_NAME}.${PROCESSED_TABLE_NAME} LIMIT 10;" \
    --query-execution-context "Database=${DATABASE_NAME}" \
    --result-configuration "OutputLocation=s3://${ATHENA_RESULTS_BUCKET}/" \
    --region "${REGION}" \
    --query 'QueryExecutionId' \
    --output text \
    --no-cli-pager)

sleep 5

echo ""
aws athena get-query-results \
    --query-execution-id "${PREVIEW_QUERY_ID}" \
    --region "${REGION}" \
    --query 'ResultSet.Rows[0:5].Data[*].VarCharValue' \
    --output text \
    --no-cli-pager | awk '{print "  " $0}'

echo ""

# Run analytics queries
run_athena_query \
    "SELECT event_type, COUNT(*) as count FROM ${DATABASE_NAME}.${PROCESSED_TABLE_NAME} GROUP BY event_type;" \
    "Count by event type"

run_athena_query \
    "SELECT HOUR(event_timestamp) as hour, COUNT(*) as event_count FROM ${DATABASE_NAME}.${PROCESSED_TABLE_NAME} GROUP BY HOUR(event_timestamp) ORDER BY hour;" \
    "Count by hour"

echo ""

# ============================================================================
# STEP 17: Verify S3 Output
# ============================================================================
echo "Step 17: Verifying S3 output files..."

echo "  Files in processed bucket:"
aws s3 ls "s3://${PROCESSED_BUCKET}/clickstream_processed/" --recursive --region "${REGION}" --no-cli-pager | head -10

echo ""

# ============================================================================
# COMPLETION
# ============================================================================
echo "========================================="
echo "✓ Pipeline Setup Complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Raw bucket: s3://${RAW_BUCKET}"
echo "  - Processed bucket: s3://${PROCESSED_BUCKET}"
echo "  - Database: ${DATABASE_NAME}"
echo "  - Raw table: ${TABLE_NAME}"
echo "  - Processed table: ${PROCESSED_TABLE_NAME}"
echo "  - ETL Job: ${ETL_JOB_NAME}"
echo ""
echo "Next Steps:"
echo "  1. Set up S3 event notifications to trigger crawler automatically"
echo "  2. Configure CloudWatch alarms for monitoring"
echo "  3. Set up Glue job triggers for automated processing"
echo ""
echo "Query your data in Athena:"
echo "  SELECT * FROM ${DATABASE_NAME}.${PROCESSED_TABLE_NAME} LIMIT 10;"
echo ""