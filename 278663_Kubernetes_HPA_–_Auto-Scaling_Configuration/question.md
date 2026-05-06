# Kubernetes HPA – Auto-Scaling Configuration


## Context

### Company Background

**Company Name:** ShopFast E-commerce  
**Industry:** Online Retail and E-commerce  
**Scale:** Rapidly growing company (250 employees)  

**Core Business:**  
ShopFast operates an online shopping platform serving:
- 2 million customers  
- Approximately 50,000 daily orders  
- Annual Recurring Revenue (ARR): $100M  

---

### The Incident / Problem

**What happened:**  
On Black Friday morning, the ShopFast API crashed under extreme traffic load. Although a Horizontal Pod Autoscaler (HPA) existed, it failed to scale the application correctly. Investigation revealed multiple misconfigurations:
- The Deployment was missing CPU and memory resource requests, causing HPA metrics to show `unknown`
- `minReplicas` was set to 1, resulting in no high availability
- `maxReplicas` was set to 100, risking cluster resource exhaustion
- CPU utilization target was set to 30 percent, leading to over-provisioning
- Only CPU metrics were configured, ignoring memory-intensive workloads

**When it occurred:**  
Black Friday at 6:00 AM, during the start of peak shopping traffic.

**Impact on the business:**
- Complete site outage for 45 minutes during peak sales
- Loss of 15,000 orders worth $2.5M
- 50,000 customers unable to complete purchases
- Significant social media backlash
- Stock price dropped by 8 percent
- Competitors gained market share during the outage
- Public apology issued by the CEO
- Engineering team forced into emergency overtime
- Risk of missing quarterly revenue targets by $10M
- Loss of customer trust during the most critical sales period

---

### Symptoms Observed

- HPA metrics showing `unknown/unknown` for CPU and memory
- Only one pod running during traffic surge
- HPA unable to calculate scaling decisions
- `kubectl get hpa` displays `<unknown>` metrics
- Pod CPU usage reached 100 percent with no scaling action
- Manual scaling required to recover
- No memory monitoring despite memory-intensive behavior

---

### Root Cause Analysis

**Primary Cause:**  
The Deployment was missing CPU and memory resource requests, which are mandatory for HPA to calculate utilization percentages. Additionally, the HPA configuration had unsafe replica limits, inefficient scaling thresholds, and incomplete metric coverage.

**Contributing Factors:**
- Lack of understanding that resource requests are required for HPA
- HPA configuration copied from an example without validation
- No autoscaling tests before production deployment
- `minReplicas` set to 1, creating a single point of failure
- `maxReplicas` set excessively high without cost safeguards
- CPU utilization target set too low
- Memory usage not monitored
- No scaling behavior configuration for stability
- No load testing with autoscaling enabled
- Missing alerts for HPA health

---

### Why This Matters

E-commerce platforms experience extreme and unpredictable traffic spikes during sales events. Without properly configured autoscaling, applications cannot handle demand, resulting in lost revenue, reputational damage, and competitive disadvantage. HPA is a critical reliability component but only works when correctly configured.

---

### Your Mission

**Your Role:** Senior Platform Engineer / Site Reliability Engineer  

**Assigned By:**  
The VP of Engineering has escalated this as a P0 incident. Leadership requires a permanent fix before Cyber Monday.

**Objective:**  
Fix all HPA misconfigurations by adding resource requests to the Deployment, configuring safe replica limits, setting efficient CPU and memory targets, and verifying that HPA can calculate metrics and scale the application.

---

### Success Criteria

- Deployment includes CPU and memory resource requests
- HPA displays actual metric values instead of `unknown`
- `minReplicas` set to at least 2
- `maxReplicas` set to a reasonable limit (10–20)
- CPU utilization target set between 70 and 80 percent
- Memory utilization metric configured with an 80 percent target
- HPA successfully scales or maintains replicas based on metrics
- System is ready to handle Cyber Monday traffic

---

## Task Description

### Lab Environment Setup

**Provided Resources:**
- Kubernetes cluster with metrics-server installed
- `kubectl` CLI access with cluster-admin permissions
- Pre-deployed ShopFast API with a broken HPA configuration

**Credentials / Access:**
- All `kubectl` commands work directly
- Metrics server is available for HPA calculations

---

### Current Situation

- Deployment exists without CPU or memory resource requests
- HPA exists but shows `unknown` metrics
- Application does not autoscale under load

Your task is to correct the Deployment and HPA configuration.

---

## Tasks Breakdown

---

### Task 1: Examine Current Configuration

**Objective:**  
Identify all misconfigurations in the Deployment and HPA.

**Steps:**
1. Inspect the Deployment for missing resource requests
2. Review the HPA configuration
3. Check HPA status and reported metrics
4. Identify all six configuration issues

**Expected Outcome:**  
Clear understanding of all existing problems.

---

### Task 2: Fix Deployment Resource Requests

**Objective:**  
Add required resource requests so HPA can function.

**Steps:**
1. Edit the Deployment YAML
2. Add `requests.cpu: 100m`
3. Add `requests.memory: 128Mi`
4. Apply the updated Deployment
5. Wait for pods to restart

**Expected Outcome:**  
Deployment includes CPU and memory resource requests.

---

### Task 3: Fix HPA Replica Limits

**Objective:**  
Configure safe and appropriate replica limits.

**Steps:**
1. Edit the HPA YAML
2. Change `minReplicas` from 1 to 2
3. Change `maxReplicas` from 100 to 10
4. Apply the updated HPA

**Expected Outcome:**  
HPA uses safe replica limits.

---

### Task 4: Fix CPU Target

**Objective:**  
Set an efficient CPU utilization target.

**Steps:**
1. Locate the CPU metric in the HPA specification
2. Change `averageUtilization` from 30 to 70
3. Apply the updated HPA

**Expected Outcome:**  
CPU utilization target is set to 70 percent.

---

### Task 5: Add Memory Metric

**Objective:**  
Enable autoscaling based on memory usage.

**Steps:**
1. Add a memory metric to the HPA metrics array
2. Set memory `averageUtilization` to 80
3. Apply the updated HPA

**Expected Outcome:**  
HPA monitors both CPU and memory metrics.

---

### Task 6: Verify HPA Works

**Objective:**  
Confirm that HPA can calculate metrics and scale.

**Steps:**
1. Wait 1–2 minutes for metrics collection
2. Run `kubectl get hpa` and verify actual percentages are shown
3. Confirm replica count is at least `minReplicas`
4. Optionally generate load to observe scaling behavior

**Expected Outcome:**  
HPA shows real metrics and maintains or scales replicas correctly.

---

## Verification Requirements

You must verify:

- Deployment has `resources.requests.cpu` configured
- Deployment has `resources.requests.memory` configured
- HPA exists and targets the correct Deployment
- HPA `minReplicas` is at least 2
- HPA `maxReplicas` is between 5 and 20
- HPA CPU target is between 50 and 90 percent
- HPA has a memory metric configured
- HPA status shows actual metrics and not `unknown`
