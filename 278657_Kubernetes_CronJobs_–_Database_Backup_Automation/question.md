# Kubernetes CronJobs – Database Backup Automation


## Context

### Company Background

**Company Name:** DataStore Analytics  
**Industry:** Data Analytics and Business Intelligence  
**Scale:** Mid-size company (200 employees)  

**Core Business:**  
DataStore Analytics provides a real-time analytics platform for:
- 500 enterprise clients  
- Processing approximately 100 TB of data daily  
- Annual Recurring Revenue (ARR): $8M  

---

### The Incident / Problem

**What happened:**  
On Monday morning, the data engineering team discovered that production database backups had not been functioning correctly for the past week. The Kubernetes CronJob responsible for nightly backups was creating Jobs that either failed repeatedly, ran concurrently (corrupting backups), or accumulated endlessly in the cluster, causing resource exhaustion.

**When it occurred:**  
Discovered Monday at 9:00 AM, but the issue has existed since the CronJob was deployed last Tuesday.

**Impact on the business:**
- Seven days without a successful database backup  
- Over 200 Job objects (successful and failed) consuming cluster resources  
- Primary database server running at 85% capacity due to accumulated Job pods  
- Inability to restore data in case of disaster  
- Violations of compliance requirements (SOC 2, GDPR data retention)  
- Two major clients ($1.2M ARR combined) conducting security audits this week  
- Escalation to the CTO from the compliance team  
- High risk of failing the upcoming SOC 2 audit if not resolved within 48 hours  

---

### Symptoms Observed

- Multiple backup Jobs running simultaneously  
- Hundreds of completed Job objects cluttering the namespace  
- Some Jobs failing and retrying endlessly  
- Cluster resource warnings caused by pod accumulation  
- No clean or usable backup files in storage  
- `kubectl get jobs` shows more than 200 Job objects  

---

### Root Cause Analysis

**Primary Cause:**  
A junior engineer deployed a CronJob using an incorrect example found online. The CronJob contains multiple misconfigurations, including an incorrect schedule, missing job history limits, no concurrency control, incorrect restart policy, and missing failure retry limits.

**Contributing Factors:**
- No code review process for CronJob configurations  
- Lack of familiarity with CronJob and Job best practices  
- No testing in a staging environment  
- Missing validation of cron schedule syntax  
- No monitoring or alerting on Job failures  
- Insufficient understanding of Job restart policies  
- Copy-paste configuration without understanding parameters  

---

### Why This Matters

Database backups are critical for disaster recovery and regulatory compliance. Without reliable backups, the organization risks permanent data loss, audit failures, regulatory penalties, and loss of customer trust. Concurrent backups can corrupt data, and unlimited Job accumulation can exhaust cluster resources.

---

### Your Mission

**Your Role:** Senior DevOps Engineer  

**Assigned By:**  
The VP of Engineering has escalated this issue as a critical priority. The compliance team requires proof of working backups by Wednesday.

**Objective:**  
Fix all misconfigurations in the `database-backup` CronJob so that it runs reliably, safely, and in compliance with best practices.

---

### Success Criteria

- CronJob runs once per day at 2:00 AM UTC  
- Only the last 3 successful Jobs are retained  
- Only the last 1 failed Job is retained  
- Concurrent Job execution is prevented  
- Failed Jobs retry a maximum of 3 times  
- Correct restart policy is used for Jobs  
- Manual test Job completes successfully  
- All fixes are documented for the compliance team  

---

## Task Description

### Lab Environment Setup

**Provided Resources:**
- Pre-configured Kubernetes cluster  
- `kubectl` CLI access with cluster-admin permissions  
- Namespace creation permissions  
- A pre-deployed, broken CronJob  

**Credentials / Access:**
- All `kubectl` commands work directly in the environment  
- No additional credentials are required  

---

### Current Situation

- Namespace: `datastore-prod`  
- A CronJob exists with multiple misconfigurations  
- Jobs are accumulating and running incorrectly  

Your task is to identify and fix all issues in the CronJob configuration.

---

## Tasks Breakdown

---

### Task 1: Examine the Broken CronJob

**Objective:**  
Understand the current CronJob configuration and identify all issues.

**Steps:**
1. View the CronJob in the `datastore-prod` namespace  
2. Check the cron schedule format  
3. Review Job history retention settings  
4. Examine the concurrency policy  
5. Check the backoff limit and restart policy  
6. List existing Jobs to observe accumulation  

**Expected Outcome:**  
A clear understanding of all six misconfigurations.

---

### Task 2: Fix the CronJob Schedule

**Objective:**  
Ensure the CronJob runs at exactly 2:00 AM UTC every day.

**Steps:**
1. Verify the current schedule  
2. Update the schedule to the correct cron expression: `0 2 * * *`  
3. Confirm understanding of cron syntax (minute, hour, day, month, weekday)  

**Expected Outcome:**  
CronJob is scheduled to run daily at 2:00 AM UTC.

---

### Task 3: Configure Job History Limits

**Objective:**  
Prevent unlimited accumulation of completed Jobs.

**Steps:**
1. Add `successfulJobsHistoryLimit: 3`  
2. Add `failedJobsHistoryLimit: 1`  
3. Understand why limiting Job history is important  

**Expected Outcome:**  
Kubernetes automatically cleans up old Job objects.

---

### Task 4: Set Concurrency Policy

**Objective:**  
Prevent overlapping backup Jobs.

**Steps:**
1. Add `concurrencyPolicy: Forbid`  
2. Understand the three options: `Allow`, `Forbid`, `Replace`  
3. Identify why `Forbid` is appropriate for database backups  

**Expected Outcome:**  
Only one backup Job can run at a time.

---

### Task 5: Configure Failure Handling

**Objective:**  
Ensure proper retry behavior and pod restart handling.

**Steps:**
1. Add `backoffLimit: 3` under `jobTemplate.spec`  
2. Set `restartPolicy: OnFailure` in the pod template  
3. Understand why `restartPolicy: Always` is invalid for Jobs  

**Expected Outcome:**  
Jobs retry up to three times and pods restart only on failure.

---

### Task 6: Test and Verify

**Objective:**  
Confirm the CronJob works correctly after fixes.

**Steps:**
1. Apply the corrected CronJob configuration  
2. Create a manual test Job from the CronJob  
3. Wait for the Job to complete  
4. Inspect Job logs  
5. Verify successful completion  
6. Clean up the test Job  

**Expected Outcome:**  
The manual Job runs successfully and completes without errors.

