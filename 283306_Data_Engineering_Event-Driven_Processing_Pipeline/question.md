# Creating a Data Engineering Event-Driven Processing Pipeline (S3 -> SNS -> SQS -> Lambda -> S3)

### Before you start, please RUN the following command to set up your Infra:

`sudo ./pipeline.sh`

### The password for the above command is `user@123!`

---

## Background

You are part of the **Data Engineering Team** at a fast-growing enterprise called **Scaler Analytics**.

The organization operates across multiple departments and processes **employee payroll data every month**.

The HR and Finance teams generate salary files and upload them into a centralized cloud storage system for further analytics.

---

## Architecture Overview

The system is designed as an **event-driven pipeline** that automatically reacts to file uploads and processes them end-to-end:

```
| Step | Action |
|------|--------|
| 1 | Detect when a salary file is uploaded |
| 2 | Notify downstream systems |
| 3 | Queue processing requests reliably |
| 4 | Process the data automatically |
| 5 | Generate aggregated outputs |
| 6 | Store final reports for analytics |
```

### Target Architecture

You must build the pipeline using the following AWS services in order:
```
File Upload → S3 (Upload Bucket)
           → SNS (Notification)
           → SQS (Queueing)
           → Lambda (Processing)
           → S3 (Processed Bucket)
```

```

| Service | Role |
|---------|------|
| Amazon S3 | Stores input salary files and output aggregated reports |
| Amazon SNS | Publishes notification when a new file arrives |
| Amazon SQS | Buffers and reliably delivers messages to Lambda |
| AWS Lambda | Processes the CSV and writes aggregated output |
```

---

## Resource Naming Convention

All resources follow predictable names tied to your AWS Account ID:
```bash
UPLOAD_BUCKET="salary-file-uploads-${ACCOUNT_ID}"
PROCESSED_BUCKET="salary-processed-bucket-${ACCOUNT_ID}"
LAMBDA_NAME="salaryProcessor"
SQS_NAME="ImageProcessingDLQ"
REGION="us-west-2"
```

---

## Input Data Description

**File to process:** `Scalersalary_Mar.csv`

**Upload location:** `s3://salary-file-uploads-${ACCOUNT_ID}/input/`

**Schema:** `emp_id, name, salary, month, dept_id`

```
| Column | Description |
|--------|-------------|
| emp_id | Unique employee ID |
| name | Employee name |
| salary | Monthly salary paid |
| month | Salary month (e.g. Mar) |
| dept_id | Department identifier |
```

---

## Output

**Output location:** `s3://salary-processed-bucket-${ACCOUNT_ID}/output/deptMonthAggSalary${ACCOUNT_ID}.csv`

Run this command to upload the input file:
```bash
aws s3 cp ./salary_data/Scalersalary_Mar.csv s3://salary-file-uploads-${ACCOUNT_ID}/input/Scalersalary_Mar.csv
```

**Output schema:** `dept_id, month, total_salary`

The output must contain **one aggregated row per department per month**, with the total salary summed across all employees in that department.

---

## Your Task

Implement the `salaryProcessor` Lambda function to:

1. **Trigger** automatically as soon as a `.csv` file arrives in `input/`
2. **Parse** the incoming SQS message to identify the uploaded file
3. **Download** the CSV from the upload S3 bucket
4. **Aggregate** salary data by `dept_id` and `month` using SUM
5. **Write** the result back to the processed bucket with the correct naming convention

##  Optional: Using Pandas in Your Lambda

If you'd like to use `pandas` for data processing, you can attach the **AWS SDK for Pandas** managed layer directly from the Lambda Console — no zip or upload needed.

### Steps to Attach the Pandas Layer

1. In the Lambda Console, go to **Functions** → click on **`salaryProcessor`**
2. Scroll down to the **Layers** section at the bottom of the page
3. Click **Add a layer**
4. Select **AWS layers**
5. In the dropdown, search for and select **`AWSSDKPandas-Python312`**
6. Select the latest version
7. Click **Add**

The **Layers** box will now show **1 layer attached** and you can use pandas directly in your Lambda code:
```python
import pandas as pd
```

---

## Success Criteria

- `s3://salary-processed-bucket-${ACCOUNT_ID}/output/` contains exactly **one output file**
- The file is named `deptMonthAggSalary${ACCOUNT_ID}.csv`
- The file has the header `dept_id,month,total_salary`
- All 5 departments (`101`–`105`) are present in the output
- Salary values are correctly aggregated (SUM) per department per month
- No duplicate `(dept_id, month)` rows exist in the output

---

## Deliverable

A working, production-ready Lambda function that satisfies all functional requirements above in `us-west-2`, triggered automatically on file upload with no manual intervention required after the CSV is placed in the input bucket.