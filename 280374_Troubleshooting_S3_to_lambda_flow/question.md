# Troubleshooting an Event-Driven Image Processing Pipeline (S3 → Lambda)

## Background

Your team maintains an **event-driven image processing pipeline** built on AWS.  
The system previously worked in a lower environment but is **not functioning in production**.

Customers are actively uploading images, but **no images are being processed**.

You have been asked to investigate and fix the issue **as quickly as possible**.

---

## Architecture Overview

The system is designed as follows:

1. Users upload image files to an Amazon S3 bucket
2. An S3 event notification invokes a Lambda function
3. The Lambda function processes the image
4. The processed image is written to a different S3 bucket
5. Failed invocations are sent to a Dead Letter Queue (DLQ)

---

## Known Symptoms

- Uploading files to the upload bucket does **not** trigger the Lambda function
- No objects appear in the processed images bucket
- No new CloudWatch Logs are generated for the Lambda function
- No errors are immediately visible

The issue did **not** exist in the development environment.

---

## Constraints

- You may not recreate resources
- You may not change resource names
- You must fix the existing configuration
- Assume IAM permissions *might* be incomplete or incorrect

---

## Resource Naming Convention

All resources follow predictable names:

```bash
UPLOAD_BUCKET="image-uploads-${ACCOUNT_ID}"
PROCESSED_BUCKET="processed-images-${ACCOUNT_ID}"
LAMBDA_NAME="ImageProcessor"
DLQ_NAME="ImageProcessingDLQ"
REGION="us-west-2"
````

---

## Functional Requirements

The system must meet **all** of the following requirements once fixed:

* The Lambda function is triggered automatically by S3 uploads
* Only objects uploaded under the `uploads/` prefix trigger the Lambda
* Only image files (`.jpg`, `.png`, `.gif`) trigger the Lambda
* The Lambda function writes processed objects to:

  ```
  s3://processed-images-${ACCOUNT_ID}/processed/
  ```
* Uploads outside the expected prefix must not trigger processing
* Non-image files must not be processed
* Failed Lambda invocations must be sent to the Dead Letter Queue
* Processed objects must **not** re-trigger the Lambda function

---

## Your Task

You are responsible for identifying **all configuration issues** preventing the pipeline from working and fixing them.

This may include (but is not limited to):

* Event source configuration
* Invocation permissions
* Filtering rules
* Lambda configuration
* Error handling configuration
* Architectural edge cases

You are expected to:

* Investigate the current state of the system
* Apply minimal, correct changes
* Validate that the system behaves as intended

---

## Verification

Once you believe the system is fixed:

1. Upload multiple image files to the correct prefix
2. Upload non-image files to the same prefix
3. Upload files outside the expected prefix
4. Confirm:

   * Only valid images are processed
   * Processed images appear in the processed bucket
   * No unexpected Lambda executions occur
   * Failures are routed to the Dead Letter Queue
   * CloudWatch Logs show successful executions

---

## Deliverable

A working production system that satisfies **all functional requirements** without introducing new issues.
