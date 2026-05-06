# Kubernetes Secrets and Environment Variables
## Story / Context

### Company Background

**Company Name:** HealthSync Medical  
**Industry:** Healthcare Technology  
**Scale:** Enterprise (1,200 employees)  

**Core Business:**  
HealthSync Medical provides an Electronic Health Records (EHR) platform used by:
- 350 hospitals
- 5,000 medical practices
- Managing health data for 12 million patients
- Annual Recurring Revenue (ARR): $45M

---

### The Incident / Problem

**What happened:**  
During a routine quarterly security audit on Monday morning, the compliance team discovered that database credentials were hardcoded directly in a Kubernetes Deployment manifest as plaintext environment variables. This was immediately flagged as a P0 HIPAA compliance violation.

**When it occurred:**  
Discovered during the quarterly audit, but the issue has existed for approximately 6 months.

**Impact on the business:**
- Immediate HIPAA compliance violation with potential fines up to $1.5M per violation
- Database credentials exposed in version control (GitHub)
- Three major hospital networks (30% of revenue) received compliance alerts
- External security auditor from the largest client arriving in 48 hours
- Risk of losing SOC 2 certification within 72 hours
- Potential loss of $15M in new contracts

---

### Symptoms Observed

- Deployment YAML in Git contains plaintext database credentials
- Sensitive environment variables visible using `kubectl describe pod`
- Any user with Kubernetes access can read database credentials
- CI/CD security scanner flagged hardcoded secrets

---

### Root Cause Analysis

**Primary Cause:**  
The development team hardcoded the database password directly in the Deployment manifest using literal environment variable values instead of referencing a Kubernetes Secret.

**Contributing Factors:**
- No Kubernetes secrets management training
- No code review checks for hardcoded credentials
- Lack of automated security scanning in CI/CD pipelines
- Security deprioritized during initial development
- No enforced secrets management policies

---

### Why This Matters

Healthcare systems are subject to strict regulations such as HIPAA and HITECH. Exposed database credentials can lead to unauthorized access to Protected Health Information (PHI), regulatory fines, loss of customer trust, and potential legal consequences. This issue represents a legal and regulatory risk, not just a technical flaw.

---

### Your Mission

**Your Role:** Senior Security Engineer / DevSecOps Lead  

**Assigned By:**  
The Chief Information Security Officer (CISO), with direct involvement from the CTO and CEO.

**Timeline:**  
An external auditor arrives within 48 hours and requires evidence of full remediation.

**Objective:**  
Migrate hardcoded database credentials from the Kubernetes Deployment to a Kubernetes Secret and update the Deployment to securely reference the Secret.

---

### Success Criteria

- Database password removed from Deployment manifest
- Password stored in a Kubernetes Secret
- Deployment uses `secretKeyRef` to reference the Secret
- Pods restart successfully
- Application continues to connect to the database
- Clear remediation steps documented for the security team

---

## Task Description

### Lab Environment Setup

**Provided Resources:**
- Pre-configured Kubernetes cluster
- `kubectl` CLI access
- Permissions to create Secrets and modify Deployments

**Credentials / Access:**
- All `kubectl` commands work without additional configuration
- No external credentials required

---

### Current Situation

- Namespace: `healthsync-prod`
- Deployment: `patient-api`
- Database credentials are hardcoded as plaintext environment variables
- Some sensitive data is incorrectly managed using ConfigMaps

Your task is to migrate database credentials to Kubernetes Secrets.

---

## Tasks Breakdown

---

### Task 1: Examine the Current Insecure Deployment

**Objective:**  
Identify how credentials are currently exposed.

**Steps:**
1. Inspect the `patient-api` Deployment in the `healthsync-prod` namespace
2. Identify environment variables containing sensitive information
3. Locate the hardcoded database password

**Expected Outcome:**  
Clear understanding of the existing security issue.

---

### Task 2: Create a Kubernetes Secret for the Database Password

**Objective:**  
Store the database password securely in a Kubernetes Secret.

**Requirements:**
- Secret Name: `patient-db-secret`
- Namespace: `healthsync-prod`
- Secret Type: `Opaque`
- Key: `DB_PASSWORD`
- Value: `H3alth$ync2024!Secure`

**Expected Outcome:**  
A Secret exists with the database password stored securely.

---

### Task 3: Update the Deployment to Use the Secret

**Objective:**  
Replace the hardcoded password with a `secretKeyRef`.

**Steps:**
1. Edit the existing `patient-api` Deployment
2. Locate the `DB_PASSWORD` environment variable
3. Replace the literal value with a `secretKeyRef`
4. Reference:
   - Secret Name: `patient-db-secret`
   - Key: `DB_PASSWORD`
5. Keep the following environment variables unchanged:
   - `DB_HOST`
   - `DB_NAME`
   - `DB_USER`
   - `APP_NAME`
   - `LOG_LEVEL`
6. Apply the updated Deployment

**Expected Outcome:**  
The Deployment securely references the Kubernetes Secret.

---

### Verify Secure Implementation

**Objective:**  
Ensure credentials are secure and the application remains functional.

**Steps:**
1. Verify all three pods restart successfully
2. Confirm the `DB_PASSWORD` environment variable is populated in the pods
3. Ensure the database password is not visible when describing the Deployment
4. Verify the application can still connect to the database

**Expected Outcome:**  
Pods are running, credentials are secure, and the application functions normally.

---

## Verification Checklist

- Namespace `healthsync-prod` exists
- Secret `patient-db-secret` exists with key `DB_PASSWORD`
- Deployment `patient-api` updated to use `secretKeyRef`
- No plaintext credentials in Deployment YAML
- Non-sensitive environment variables remain unchanged
- All three pods restart successfully
- `DB_PASSWORD` is injected from the Kubernetes Secret
