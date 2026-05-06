# Kubernetes Persistent Storage – Database Migration


## Context

### Company Background

**Company Name:** CloudBank Financial  
**Industry:** Digital Banking and Fintech  
**Scale:** Fast-growing startup (150 employees)  

**Core Business:**  
CloudBank Financial operates an online banking platform serving:
- 50,000 customers  
- $500M in total deposits  
- Approximately 10,000 daily transactions  
- Annual Recurring Revenue (ARR): $5M  

---

### The Incident / Problem

**What happened:**  
On Thursday morning, customers began reporting that recent transactions were disappearing from their accounts. The support team discovered that every time the PostgreSQL database pod restarted—due to deployments, crashes, or node maintenance—all customer data from the past 24 hours was lost.

An investigation revealed that the PostgreSQL deployment was using `emptyDir` for storage. This means all database data was stored on ephemeral pod storage and deleted whenever the pod was removed or restarted.

**When it occurred:**  
Discovered Thursday at 8:00 AM after an overnight maintenance window caused a pod restart.

**Impact on the business:**
- Loss of 24 hours of customer transactions (500+ transactions totaling $2.3M)
- Over 200 customer complaints regarding missing deposits and transfers
- Inability to reconcile accounts or generate statements
- Federal banking regulators notified (FDIC requires transaction persistence)
- Three major funding partners threatening to withdraw investments ($10M at risk)
- CEO received emergency calls from board members
- Media coverage questioning platform reliability
- Risk of banking license suspension if not fixed immediately
- Estimated financial impact: $500K in lost transactions and $2M in regulatory fines
- Severe damage to customer trust

---

### Symptoms Observed

- Database starts empty after every pod restart
- Tables and data created since the last restart are missing
- Customer account balances and transaction history are incomplete
- `kubectl describe pod` shows `emptyDir` volume usage
- No PersistentVolumeClaim attached to the database pod
- Database data directory is empty after pod recreation

---

### Root Cause Analysis

**Primary Cause:**  
A junior developer deployed the PostgreSQL database using an `emptyDir` volume, which provides only temporary storage tied to the pod lifecycle. When the pod is deleted or restarted, all data stored in `emptyDir` is lost.

**Contributing Factors:**
- Lack of understanding of Kubernetes storage concepts
- No distinction between stateless and stateful workloads
- Deployment copied from a tutorial without validation
- No review process for database deployments
- No persistence testing before production rollout
- Incorrect assumption that container storage is persistent
- No alerts or checks for storage configuration
- Insufficient training on Kubernetes StorageClasses and PVCs

---

### Why This Matters

Databases are stateful workloads that require persistent storage to ensure data durability across pod restarts, upgrades, and failures. `emptyDir` is intended only for temporary data such as caches or scratch space and must never be used for production databases. In a banking system, loss of transaction data violates regulatory requirements and threatens the organization’s license to operate.

---

### Your Mission

**Your Role:** Senior Cloud Engineer / Database Reliability Engineer  

**Assigned By:**  
The CTO has escalated this as a P0 critical incident. The CEO, CFO, and Chief Compliance Officer are coordinating with regulators. You have full authority to implement an immediate fix.

**Objective:**  
Migrate the PostgreSQL database from ephemeral `emptyDir` storage to persistent storage using a PersistentVolumeClaim (PVC). Update the deployment, verify data persistence across pod restarts, and provide documentation to the compliance team.

---

### Success Criteria

- PersistentVolumeClaim created and bound to a PersistentVolume
- PostgreSQL deployment updated to use PVC instead of `emptyDir`
- Pod successfully mounts the persistent volume
- Data persists across pod restarts and recreations
- No data loss after deleting and recreating the pod
- Database restarts with existing data intact
- Written documentation provided for compliance
- Architecture diagram illustrating persistent storage usage

---

## Task Description

### Lab Environment Setup

**Provided Resources:**
- Kubernetes cluster with dynamic storage provisioning
- `kubectl` CLI access with cluster-admin permissions
- Pre-deployed PostgreSQL database using `emptyDir` (broken setup)
- StorageClass available (`standard` or cluster default)

**Credentials / Access:**
- All `kubectl` commands work directly in the environment
- No additional credentials are required

---

### Current Situation

- Namespace: `cloudbank-prod`
- PostgreSQL deployment exists
- Storage is configured using `emptyDir: {}`
- Data is lost on every pod restart

Your task is to migrate the database to persistent storage.

---

## Tasks Breakdown

---

### Task 1: Examine the Current Deployment

**Objective:**  
Understand the existing broken configuration.

**Steps:**
1. View the PostgreSQL deployment in the `cloudbank-prod` namespace
2. Examine the `volumes` section
3. Identify usage of `emptyDir`
4. Review the `volumeMounts` configuration
5. Understand why this setup causes data loss

**Expected Outcome:**  
Clear understanding of why `emptyDir` is unsuitable for databases.

---

### Task 2: Create a PersistentVolumeClaim

**Objective:**  
Request persistent storage from the cluster.

**Steps:**
1. Create a PVC named `postgres-pvc`
2. Set namespace to `cloudbank-prod`
3. Request `5Gi` of storage
4. Set `accessModes` to `ReadWriteOnce`
5. Specify `storageClassName: standard` (or use the default)
6. Apply the PVC
7. Verify the PVC status is `Bound`

**Expected Outcome:**  
PVC exists and is bound to a PersistentVolume.

---

### Task 3: Update the Deployment to Use the PVC

**Objective:**  
Replace `emptyDir` with a PersistentVolumeClaim.

**Steps:**
1. Edit the PostgreSQL deployment YAML
2. Locate the `volumes` section
3. Replace `emptyDir: {}` with a `persistentVolumeClaim` reference
4. Use the PVC name `postgres-pvc`
5. Keep the existing `volumeMounts` unchanged
6. Apply the updated deployment
7. Wait for the pod to restart

**Expected Outcome:**  
Deployment now uses persistent storage.

---

### Task 4: Verify Pod Mounts Persistent Volume

**Objective:**  
Ensure the pod correctly mounts the persistent volume.

**Steps:**
1. Check pod status (should be `Running`)
2. Describe the pod to verify volume mounts
3. Confirm the PVC is mounted at the expected path
4. Check events for mount-related errors

**Expected Outcome:**  
Pod successfully mounts the persistent volume.

---

### Task 5: Test Data Persistence

**Objective:**  
Confirm data survives pod restarts.

**Steps:**
1. Connect to PostgreSQL inside the pod
2. Create a test table
3. Insert sample records (simulated customer transactions)
4. Query the table to confirm data exists
5. Delete the pod to simulate a crash or restart
6. Wait for a new pod to be created
7. Reconnect to PostgreSQL
8. Query the same table
9. Verify data still exists

**Expected Outcome:**  
Data persists across pod deletion and recreation.

---

### Task 6: Document and Report

**Objective:**  
Provide proof of remediation to the compliance team.

**Steps:**
1. Capture evidence of PVC status (`Bound`)
2. Show updated deployment YAML referencing the PVC
3. Document data persistence test results
4. Create a before-and-after architecture diagram
5. Write a remediation summary for the compliance officer

**Expected Outcome:**  
Complete documentation package ready for regulators.

---

## Verification Requirements

You must verify:

- PVC `postgres-pvc` exists in namespace `cloudbank-prod`
- PVC status is `Bound`
- PVC requests `5Gi` of storage
- PVC access mode is `ReadWriteOnce`
- Deployment no longer uses `emptyDir`
- Deployment references `persistentVolumeClaim` named `postgres-pvc`
- Pod is running and healthy
- Persistent volume is mounted in the pod
- Data persists across pod restarts (tested and confirmed)
