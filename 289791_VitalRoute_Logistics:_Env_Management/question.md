# AWS Lambda Environment Variables: Fix the PII Exposure at VitalRoute Logistics

## Context

VitalRoute Logistics is a mid-size Indian last-mile delivery startup operating across 12 cities, coordinating over 800 delivery partners daily. Their core operations platform is built on AWS Lambda microservices that power their partner-facing mobile app, route assignment engine, and delivery status API.

At 2:47 AM, VitalRoute's on-call engineer received an alert: the delivery partner data API is returning raw PII — driver names, phone numbers, and bank account details — to non-admin consumers. After tracing the issue, the engineer found that the Lambda function uses an environment variable called `APP_ENV` to switch between two response modes:

- `APP_ENV=dev` returns raw, unmasked driver data intended only for internal debugging
- `APP_ENV=prod` returns properly masked data safe for external consumers

The function was deployed to production with `APP_ENV=dev` still set. The fix is straightforward — but the function does not exist yet. Your job is to set it up correctly from scratch, observe the problem, and fix it.

The application code has been prepared for you at `/home/user/vitalroute-lab/lambda_function.py`. Run the setup script first if you have not already.

### To save and exit vim: press `Ctrl + C`

---

## Environment Details

- **Region:** `us-west-2`
- **Lambda function name:** `vitalroute-delivery-fn`
- **IAM role name:** `vitalroute-lambda-role`
- **Runtime:** `python3.11`
- **Handler:** `lambda_function.lambda_handler`

---

## Tasks

### Task 1: Create the IAM Role

Create an IAM role named `vitalroute-lambda-role` that allows Lambda to assume it. Attach the `AWSLambdaBasicExecutionRole` managed policy to it.

### Task 2: Create the Lambda Function

Create the Lambda function `vitalroute-delivery-fn` using the role you just created. Set the environment variable `APP_ENV=dev` as the initial value so you can observe the problem state before fixing it.

### Task 3: Package and Deploy the Code

Navigate to the lab directory, zip the provided application code, and upload it to your Lambda function.

```bash
cd /home/user/vitalroute-lab
zip -j function.zip lambda_function.py
```

Once zipped, deploy the code to your function:

```bash
aws lambda update-function-code \
  --function-name vitalroute-delivery-fn \
  --zip-file fileb://function.zip \
  --region us-west-2
```

### Task 4: Observe the Problem

Invoke the function and inspect the response. You should see raw driver data — full name, phone number, and bank account details — exposed in the response. This is the problem state.

### Task 5: Fix the Environment Variable

Update the `APP_ENV` environment variable on the function from `dev` to `prod`.

### Task 6: Verify the Fix

Invoke the function again and confirm the response now contains masked data with no raw PII fields.

Expected response:

```json
{
  "statusCode": 200,
  "body": {
    "env": "prod",
    "data": {
      "driver_id": "DRV-9921",
      "name": "R*** S******",
      "phone": "98*****210",
      "bank_account": "HDFC-XXXXXX37",
      "route": "Koramangala-BTM",
      "status": "active"
    }
  }
}
```

---

## Notes

- Zip the code before creating the function. Lambda requires a valid deployment package at creation time.
- IAM role propagation takes a few seconds. If the Lambda creation returns a role not found error, wait 10 seconds and retry.
- Updating an environment variable does not require redeploying the code. It takes effect on the next invocation.
- Use `us-west-2` for all resources.