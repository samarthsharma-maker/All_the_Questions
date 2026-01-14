# Lab Question: Kubernetes Troubleshooting - Deployment Failures

## Template Metadata

**Difficulty Level:** HARD

**Format Type:** Assignment

**Scenario-Based:** Yes

**Estimated Time:** 90 minutes

**Technology/Topic:** Kubernetes

---

## Section 1: Story/Context

### Company Background
- **Company Name:** RetailPulse Analytics
- **Industry:** E-commerce Analytics & Business Intelligence
- **Scale:** Mid-size company (350 employees)
- **Core Business:** Provides real-time sales analytics and inventory insights to 800 retail clients, processing 50 million transactions daily and generating $12M ARR

### The Incident/Problem
- **What happened:** A junior DevOps engineer deployed a new version of the analytics processing engine to production on Friday evening. The deployment appeared to succeed, but no pods are running. The weekend sales reporting dashboard is completely blank, and clients are unable to see their sales data.
- **When it occurred:** Friday, 6:30 PM - just before the weekend retail rush
- **Impact on business:** 
  - 800 retail clients cannot access their sales dashboards
  - Critical weekend sales analytics unavailable (Black Friday is in 2 weeks - clients need data to prepare)
  - Support team receiving 200+ escalation tickets per hour
  - Three enterprise clients (15% of revenue) threatening to suspend their contracts
  - CEO received personal calls from two major retail chain CIOs
  - SLA breach penalties estimated at $45,000 if not resolved within 4 hours
- **Symptoms observed:**
  * Kubernetes dashboard shows 0/5 pods ready
  * Some pods stuck in "Pending" state
  * Some pods showing "ImagePullBackOff" error
  * Some pods in "CrashLoopBackOff" state
  * kubectl get pods shows a mix of different error states
  * The junior engineer left for the weekend and is unreachable
  * Previous deployment (v2.3) was working perfectly

### Root Cause Analysis
- **Primary cause:** The junior engineer made multiple configuration mistakes in the deployment YAML file while trying to implement "production-grade" settings from various online tutorials without fully understanding them

- **Contributing factors:**
  * No peer review process for production deployments
  * Junior engineer working alone on Friday evening without senior oversight
  * No pre-deployment validation or dry-run testing
  * Deployment YAML was copy-pasted from multiple sources without testing
  * No staging environment to test changes before production
  * Inadequate knowledge of Kubernetes scheduling, taints/tolerations, and resource management

- **Why it matters:** Analytics processing is the core product. Without it, clients cannot make data-driven decisions during their busiest sales period. The company's reputation as a reliable analytics provider is at stake. If this isn't fixed by Monday morning, client churn could cost $500K+ in annual revenue.

### Your Mission
- **Your role:** Senior Site Reliability Engineer (on-call this weekend)

- **Who assigned it:** VP of Engineering called you at 7:00 PM on Friday evening, clearly stressed. The CTO is in emergency meetings with the executive team. They need this fixed IMMEDIATELY - clients are threatening to leave. You have full authority to do whatever is needed to restore service.

- **What you need to accomplish:** 
  Debug and fix the broken deployment. Identify all configuration mistakes, correct them, and get the analytics engine running again. The deployment must have 5 healthy replicas processing transactions within the next 2 hours.

- **Success criteria:**
  * All 5 pods are in Running state with 1/1 containers ready
  * Pods are properly scheduled across available nodes
  * Analytics engine is processing transactions (can be verified by checking logs)
  * All configuration mistakes are identified and documented
  * Deployment is stable with no restart loops
  * Post-incident report documenting what was wrong and how it was fixed

---

## Section 2: Task Description

### Lab Environment Setup

**Provided Resources:**
- Kubernetes cluster with 3 worker nodes
- One node has a taint: `workload=analytics:NoSchedule`
- kubectl CLI access with cluster-admin permissions
- Pre-deployed broken deployment manifest

**Credentials/Access:**
```
All kubectl commands will work directly in the provided environment
No additional credentials required
```

**Important Notes:**
- The broken deployment is already applied to the cluster in namespace `retailpulse-prod`
- The deployment name is `analytics-engine`
- The previous working version was using image `retailpulse/analytics-engine:v2.3`
- The broken deployment is trying to use image `retailpulse/analytics-engine:v2.4`

### Tasks Breakdown

**Task 1: Assess the Damage**
- Objective: Understand the current state of the deployment and identify visible errors
- Steps required:
  1. Check the namespace `retailpulse-prod` exists and contains the deployment
  2. List all pods and observe their states
  3. Check deployment status and replica counts
  4. Review events to understand what's happening
- Expected outcome: Clear picture of which pods are failing and in what states

**Task 2: Investigate Pod Failures**
- Objective: Deep-dive into each failing pod to identify specific issues
- Steps required:
  1. Describe pods in different failure states
  2. Check pod events for scheduling failures
  3. Review image pull status
  4. Examine resource requests and limits
  5. Check for taint/toleration issues
- Expected outcome: List of all 5 configuration mistakes identified

**Task 3: Fix the Deployment**
- Objective: Correct all configuration mistakes in the deployment manifest
- Steps required:
  1. Extract the current deployment YAML
  2. Identify and fix the image name typo causing ImagePullBackOff
  3. Correct the CPU request that's too low (causing OOMKill or instability)
  4. Add missing toleration for tainted node
  5. Fix node selector that's preventing scheduling
  6. Correct any resource limit issues
  7. Apply the corrected deployment
- Expected outcome: Updated deployment YAML with all mistakes corrected

**Task 4: Verify Recovery**
- Objective: Confirm all pods are running and healthy
- Steps required:
  1. Watch pods come up successfully
  2. Verify all 5 replicas are running
  3. Check pod distribution across nodes
  4. Verify logs show analytics processing is working
  5. Confirm no pods are restarting
- Expected outcome: 5/5 pods running successfully, processing transactions

**Task 5: Document the Incident**
- Objective: Create post-incident documentation for the team
- Steps required:
  1. List all 5 mistakes found in the deployment
  2. Explain what each mistake caused
  3. Document the fix for each issue
  4. Provide recommendations to prevent this in the future
- Expected outcome: Clear documentation that can be shared with the engineering team

### Verification Requirements

**You must verify:**
- All 5 pods reach Running state with 1/1 ready status
- Pods are scheduled on appropriate nodes (including the tainted node)
- No pods are in Pending, ImagePullBackOff, or CrashLoopBackOff states
- Pods have appropriate resource requests and limits set
- Deployment successfully rolls out to 5/5 replicas
- Analytics engine logs show transaction processing
- All 5 configuration mistakes are identified and documented

---

## Section 3: Learning Outcomes

After completing this lab, you will be able to:
- Systematically troubleshoot Kubernetes deployment failures using kubectl commands
- Identify and resolve ImagePullBackOff errors caused by incorrect image references
- Debug pod scheduling failures related to taints, tolerations, and node selectors
- Understand the impact of resource requests and limits on pod stability
- Use kubectl describe, logs, and events effectively for troubleshooting
- Apply fixes to deployments and verify successful rollouts
- Document incidents for post-mortem analysis
- Recognize common Kubernetes misconfigurations that prevent pod scheduling

**Key Concepts Covered:**
- Pod lifecycle states and what causes each failure mode
- Kubernetes scheduling decisions and constraints
- Taints and tolerations for node workload segregation
- Resource requests vs limits and their impact on scheduling
- Image pull policies and registry authentication
- Node selectors and affinity rules
- Deployment rollout status and health checks

---

## Section 4: Hints and Tips

**Common Pitfalls to Avoid:**
- Don't just delete and recreate the deployment - fix the underlying configuration issues
- Check pod events carefully - they contain crucial debugging information
- Remember that some errors prevent scheduling (Pending), others happen after scheduling (CrashLoopBackOff)
- Image names are case-sensitive and must match exactly
- Tolerations must exactly match taints (key, value, and effect)
- CPU requests too low can cause unexpected behavior or scheduling issues

**Helpful Commands:**
```bash
# View all pods with their status
kubectl get pods -n retailpulse-prod -o wide

# Describe a specific pod to see detailed events
kubectl describe pod <pod-name> -n retailpulse-prod

# Check deployment status
kubectl get deployment analytics-engine -n retailpulse-prod

# View deployment rollout status
kubectl rollout status deployment/analytics-engine -n retailpulse-prod

# Get deployment YAML for editing
kubectl get deployment analytics-engine -n retailpulse-prod -o yaml > deployment.yaml

# View recent events in the namespace
kubectl get events -n retailpulse-prod --sort-by='.lastTimestamp'

# Check node taints
kubectl describe nodes | grep -i taint

# View pod logs
kubectl logs <pod-name> -n retailpulse-prod

# Edit deployment directly
kubectl edit deployment analytics-engine -n retailpulse-prod
```

**Documentation References:**
- [Debugging Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)
- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Images and Image Pull Policy](https://kubernetes.io/docs/concepts/containers/images/)

---

## Section 5: Evaluation Criteria

### Deliverables Required:

**Configuration Files/Scripts**
- Corrected deployment YAML file with all 5 mistakes fixed
- Documentation listing each mistake, its impact, and the fix applied

### Auto-Evaluation Criteria

Your solution will be automatically evaluated based on:

- Namespace `retailpulse-prod` contains the deployment `analytics-engine`
- Deployment has exactly 5 replicas configured
- All 5 pods are in Running state with 1/1 ready
- Image name is corrected to `retailpulse/analytics-engine:v2.4`
- Toleration is added for the `workload=analytics:NoSchedule` taint
- CPU requests are set to reasonable values (at least 100m)
- Memory requests are set appropriately
- At least one pod is scheduled on the tainted node
- No pods are in Pending, ImagePullBackOff, or CrashLoopBackOff states
- Deployment shows 5/5 available replicas
- No pods have restarted in the last 5 minutes

---

## Section 6: Expected Time Breakdown

| Task | Estimated Time |
|------|----------------|
| Assess deployment state | 10 minutes |
| Investigate pod failures | 25 minutes |
| Identify all 5 mistakes | 20 minutes |
| Fix deployment configuration | 15 minutes |
| Apply and verify fixes | 10 minutes |
| Document findings | 10 minutes |
| **Total** | **90 minutes** |

---

## Section 7: Technical Specifications

**Technology Stack:**
- Kubernetes - v1.28+

**Environment Details:**
- OS: Linux (kubectl client)
- Pre-installed tools: kubectl, text editor (vi/nano), yaml linters
- Cluster: 3 worker nodes, one with taint `workload=analytics:NoSchedule`

**File Locations:**
- Namespace: `retailpulse-prod`
- Deployment name: `analytics-engine`
- Broken deployment is already applied to the cluster

---

## Section 8: Ideal Solution

### Solution Overview

The deployment has 5 critical configuration mistakes that need to be fixed:
1. **Image name typo** - Image specified as `retailpulse/analytics-enigne:v2.4` instead of `retailpulse/analytics-engine:v2.4`
2. **Missing toleration** - No toleration for the `workload=analytics:NoSchedule` taint on one node
3. **Invalid node selector** - Node selector points to non-existent label `environment=production` 
4. **CPU request too low** - CPU request set to 10m which is insufficient
5. **Incorrect image pull policy** - Set to `Never` instead of `IfNotPresent` or `Always`

### Step-by-Step Solution

**Step 1: Assess Current State**
```bash
# Check namespace exists
kubectl get namespace retailpulse-prod
```

**Expected Output:**
```
NAME               STATUS   AGE
retailpulse-prod   Active   2d
```

**Check pods status:**
```bash
kubectl get pods -n retailpulse-prod -o wide
```

**Expected Output (showing various failure states):**
```
NAME                                READY   STATUS             RESTARTS   AGE
analytics-engine-7d4f8b9c5d-abc12   0/1     ImagePullBackOff   0          15m
analytics-engine-7d4f8b9c5d-def34   0/1     Pending            0          15m
analytics-engine-7d4f8b9c5d-ghi56   0/1     Pending            0          15m
analytics-engine-7d4f8b9c5d-jkl78   0/1     ImagePullBackOff   0          15m
analytics-engine-7d4f8b9c5d-mno90   0/1     Pending            0          15m
```

**Check deployment status:**
```bash
kubectl get deployment analytics-engine -n retailpulse-prod
```

**Expected Output:**
```
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
analytics-engine   0/5     5            0           15m
```

**Step 2: Investigate Failures**

**Check ImagePullBackOff pods:**
```bash
# Get one pod with ImagePullBackOff
POD_NAME=$(kubectl get pods -n retailpulse-prod | grep ImagePullBackOff | head -1 | awk '{print $1}')

# Describe it
kubectl describe pod $POD_NAME -n retailpulse-prod
```

**Expected Output (relevant section):**
```
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  5m                 default-scheduler  Successfully assigned retailpulse-prod/analytics-engine-xxx to node2
  Normal   Pulling    3m (x4 over 5m)    kubelet            Pulling image "retailpulse/analytics-enigne:v2.4"
  Warning  Failed     3m (x4 over 5m)    kubelet            Failed to pull image "retailpulse/analytics-enigne:v2.4": rpc error: code = NotFound desc = failed to pull and unpack image "docker.io/retailpulse/analytics-enigne:v2.4": failed to resolve reference "docker.io/retailpulse/analytics-enigne:v2.4": docker.io/retailpulse/analytics-enigne:v2.4: not found
  Warning  Failed     3m (x4 over 5m)    kubelet            Error: ErrImagePull
  Normal   BackOff    2m (x6 over 5m)    kubelet            Back-off pulling image "retailpulse/analytics-enigne:v2.4"
  Warning  Failed     2m (x6 over 5m)    kubelet            Error: ImagePullBackOff
```

**Mistake #1 Found:** Image name has typo - `enigne` instead of `engine`

**Check Pending pods:**
```bash
# Get one pending pod
PENDING_POD=$(kubectl get pods -n retailpulse-prod | grep Pending | head -1 | awk '{print $1}')

# Describe it
kubectl describe pod $PENDING_POD -n retailpulse-prod
```

**Expected Output (relevant section):**
```
Events:
  Type     Reason            Age   From               Message
  ----     ------            ----  ----               -------
  Warning  FailedScheduling  5m    default-scheduler  0/3 nodes are available: 1 node(s) had untolerated taint {workload: analytics}, 2 node(s) didn't match Pod's node affinity/selector. preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

**Mistakes Found:**
- **Mistake #2:** Missing toleration for taint `workload=analytics:NoSchedule`
- **Mistake #3:** Invalid node selector (nodes don't have the label specified)

**Check deployment YAML:**
```bash
kubectl get deployment analytics-engine -n retailpulse-prod -o yaml > broken-deployment.yaml
cat broken-deployment.yaml
```

**Expected Output (relevant sections showing mistakes):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-engine
  namespace: retailpulse-prod
spec:
  replicas: 5
  selector:
    matchLabels:
      app: analytics-engine
  template:
    metadata:
      labels:
        app: analytics-engine
    spec:
      nodeSelector:
        environment: production    # MISTAKE #3: This label doesn't exist on nodes
      containers:
      - name: analytics
        image: retailpulse/analytics-enigne:v2.4    # MISTAKE #1: Typo in image name
        imagePullPolicy: Never    # MISTAKE #5: Should be IfNotPresent or Always
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 10m              # MISTAKE #4: Too low, should be at least 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
      # MISTAKE #2: Missing tolerations section for tainted node
```

**Step 3: Fix All Mistakes**

**Create corrected deployment YAML:**
```bash
cat > fixed-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-engine
  namespace: retailpulse-prod
  labels:
    app: analytics-engine
    version: v2.4
spec:
  replicas: 5
  selector:
    matchLabels:
      app: analytics-engine
  template:
    metadata:
      labels:
        app: analytics-engine
        version: v2.4
    spec:
      # FIX #2: Add toleration for tainted node
      tolerations:
      - key: workload
        operator: Equal
        value: analytics
        effect: NoSchedule
      
      # FIX #3: Remove invalid node selector
      # nodeSelector:
      #   environment: production
      
      containers:
      - name: analytics
        # FIX #1: Correct image name typo
        image: retailpulse/analytics-engine:v2.4
        
        # FIX #5: Change to proper image pull policy
        imagePullPolicy: IfNotPresent
        
        ports:
        - containerPort: 8080
        
        resources:
          requests:
            # FIX #4: Increase CPU request to reasonable value
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        
        env:
        - name: LOG_LEVEL
          value: info
        - name: PROCESSING_THREADS
          value: "4"
EOF
```

**Apply the fixed deployment:**
```bash
kubectl apply -f fixed-deployment.yaml
```

**Expected Output:**
```
deployment.apps/analytics-engine configured
```

**Step 4: Verify Recovery**

**Watch the rollout:**
```bash
kubectl rollout status deployment/analytics-engine -n retailpulse-prod
```

**Expected Output:**
```
Waiting for deployment "analytics-engine" rollout to finish: 0 of 5 updated replicas are available...
Waiting for deployment "analytics-engine" rollout to finish: 1 of 5 updated replicas are available...
Waiting for deployment "analytics-engine" rollout to finish: 2 of 5 updated replicas are available...
Waiting for deployment "analytics-engine" rollout to finish: 3 of 5 updated replicas are available...
Waiting for deployment "analytics-engine" rollout to finish: 4 of 5 updated replicas are available...
deployment "analytics-engine" successfully rolled out
```

**Check all pods are running:**
```bash
kubectl get pods -n retailpulse-prod -o wide
```

**Expected Output:**
```
NAME                                READY   STATUS    RESTARTS   AGE   NODE
analytics-engine-6c8d9f7b5a-abc12   1/1     Running   0          2m    node1
analytics-engine-6c8d9f7b5a-def34   1/1     Running   0          2m    node2
analytics-engine-6c8d9f7b5a-ghi56   1/1     Running   0          2m    node3-tainted
analytics-engine-6c8d9f7b5a-jkl78   1/1     Running   0          2m    node1
analytics-engine-6c8d9f7b5a-mno90   1/1     Running   0          2m    node2
```

**Verify deployment status:**
```bash
kubectl get deployment analytics-engine -n retailpulse-prod
```

**Expected Output:**
```
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
analytics-engine   5/5     5            5           25m
```

**Check that at least one pod is on the tainted node:**
```bash
kubectl get pods -n retailpulse-prod -o wide | grep node3-tainted
```

**Expected Output:**
```
analytics-engine-6c8d9f7b5a-ghi56   1/1     Running   0          3m    node3-tainted
```

**Verify pods are processing (check logs):**
```bash
POD_NAME=$(kubectl get pods -n retailpulse-prod -l app=analytics-engine -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD_NAME -n retailpulse-prod --tail=20
```

**Expected Output:**
```
2024-12-30 20:15:23 INFO  Starting analytics engine v2.4
2024-12-30 20:15:23 INFO  Connecting to data pipeline...
2024-12-30 20:15:24 INFO  Connection established
2024-12-30 20:15:24 INFO  Processing thread pool initialized with 4 threads
2024-12-30 20:15:25 INFO  Processing transaction batch 1 (500 transactions)
2024-12-30 20:15:26 INFO  Processing transaction batch 2 (500 transactions)
2024-12-30 20:15:27 INFO  Processing transaction batch 3 (500 transactions)
2024-12-30 20:15:28 INFO  Analytics engine healthy and processing
```

### Verification Commands

**Verify all pods running:**
```bash
kubectl get pods -n retailpulse-prod
```

**Expected Output:**
All 5 pods show `1/1 Running` with no restarts

**Verify deployment health:**
```bash
kubectl get deployment analytics-engine -n retailpulse-prod
```

**Expected Output:**
`5/5` replicas ready and available

**Verify toleration is working (pod on tainted node):**
```bash
kubectl get pods -n retailpulse-prod -o wide | awk '{print $1,$7}' | grep -E "node3|taint"
```

**Expected Output:**
At least one pod scheduled on the tainted node

**Verify correct image is being used:**
```bash
kubectl get pods -n retailpulse-prod -o jsonpath='{.items[0].spec.containers[0].image}'
```

**Expected Output:**
```
retailpulse/analytics-engine:v2.4
```

**Verify resource requests:**
```bash
kubectl get pods -n retailpulse-prod -o jsonpath='{.items[0].spec.containers[0].resources}'
```

**Expected Output:**
```
{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}
```

### Complete Solution Files

**fixed-deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-engine
  namespace: retailpulse-prod
  labels:
    app: analytics-engine
    version: v2.4
spec:
  replicas: 5
  selector:
    matchLabels:
      app: analytics-engine
  template:
    metadata:
      labels:
        app: analytics-engine
        version: v2.4
    spec:
      tolerations:
      - key: workload
        operator: Equal
        value: analytics
        effect: NoSchedule
      
      containers:
      - name: analytics
        image: retailpulse/analytics-engine:v2.4
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        env:
        - name: LOG_LEVEL
          value: info
        - name: PROCESSING_THREADS
          value: "4"
```

**incident-report.md:**
```markdown
# Post-Incident Report: Analytics Engine Deployment Failure

## Incident Summary
- **Date:** Friday, December 30, 2024, 6:30 PM
- **Duration:** 2 hours
- **Impact:** 800 clients unable to access analytics dashboards
- **Root Cause:** Multiple configuration errors in deployment manifest

## Mistakes Identified and Fixed

### Mistake #1: Image Name Typo
**Problem:** Image specified as `retailpulse/analytics-enigne:v2.4` (typo: "enigne")
**Impact:** Pods couldn't pull image, resulting in ImagePullBackOff
**Fix:** Corrected to `retailpulse/analytics-engine:v2.4`
**Prevention:** Implement pre-deployment validation, use image digest references

### Mistake #2: Missing Toleration
**Problem:** No toleration for node taint `workload=analytics:NoSchedule`
**Impact:** Pods couldn't schedule on 1/3 of available nodes, reducing capacity
**Fix:** Added toleration:
```yaml
tolerations:
- key: workload
  operator: Equal
  value: analytics
  effect: NoSchedule
```
**Prevention:** Document cluster node taints, use admission webhooks to validate tolerations

### Mistake #3: Invalid Node Selector
**Problem:** Node selector referenced non-existent label `environment=production`
**Impact:** Pods couldn't schedule on any nodes
**Fix:** Removed invalid node selector
**Prevention:** Validate node labels before deployment, maintain label inventory

### Mistake #4: CPU Request Too Low
**Problem:** CPU request set to 10m (insufficient for analytics workload)
**Impact:** Potential pod instability, poor performance, scheduling issues
**Fix:** Increased to 100m based on application requirements
**Prevention:** Establish resource baselines through load testing, use VPA

### Mistake #5: Incorrect Image Pull Policy
**Problem:** Image pull policy set to `Never` instead of `IfNotPresent`
**Impact:** Prevented pulling images from registry even when not cached
**Fix:** Changed to `IfNotPresent`
**Prevention:** Use default values unless specific requirement exists

## Recommendations

1. **Mandatory Code Review:** All production deployments require peer review
2. **Staging Environment:** Test all changes in staging before production
3. **Deployment Validation:** Implement kubectl dry-run and validation checks
4. **Automated Testing:** Add CI/CD pipeline checks for common misconfigurations
5. **On-Call Coverage:** Never deploy on Friday evening without senior engineer available
6. **Documentation:** Create deployment checklist and troubleshooting guide
7. **Training:** Provide Kubernetes training for junior engineers
8. **Monitoring:** Implement alerts for deployment failures and pod scheduling issues
```

### Key Points in Solution

- Image name typos are common and cause ImagePullBackOff - always verify image names
- Tolerations must exactly match node taints (key, value, effect) for pods to schedule on tainted nodes
- Node selectors reference node labels - ensure labels exist before using them
- CPU requests too low can cause scheduling issues and performance problems
- Image pull policy `Never` only works with locally cached images
- Always test deployments in non-production before applying to production
- Use `kubectl describe pod` to get detailed error messages and events
- Pod status transitions: Pending → ContainerCreating → Running (or various error states)

---

## Section 9: Test Cases

### Test Case 1: Namespace and Deployment Existence
**Purpose:** Verify the deployment exists in the correct namespace

**Test Logic:**
```bash
kubectl get deployment analytics-engine -n retailpulse-prod --no-headers
```

**Success Criteria:**
- Command exits with code 0
- Deployment exists

**Failure Message:**
```
Lab Failed: Deployment 'analytics-engine' does not exist in namespace 'retailpulse-prod'
```

---

### Test Case 2: Replica Count Check
**Purpose:** Verify deployment has 5 replicas configured

**Test Logic:**
```bash
REPLICAS=$(kubectl get deployment analytics-engine -n retailpulse-prod -o jsonpath='{.spec.replicas}')
if [ "$REPLICAS" != "5" ]; then
    exit 1
fi
```

**Success Criteria:**
- Deployment specifies exactly 5 replicas

**Failure Message:**
```
Lab Failed: Deployment does not have 5 replicas configured (found: X)
```

---

### Test Case 3: All Pods Running
**Purpose:** Verify all 5 pods are in Running state

**Test Logic:**
```bash
# Wait up to 120 seconds for pods to be ready
for i in {1..120}; do
    RUNNING_PODS=$(kubectl get pods -n retailpulse-prod -l app=analytics-engine --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    if [ "$RUNNING_PODS" -eq 5 ]; then
        break
    fi
    sleep 1
done

if [ "$RUNNING_PODS" -ne 5 ]; then
    exit 1
fi
```

**Success Criteria:**
- All 5 pods are in Running phase
- Pods show 1/1 ready

**Failure Message:**
```
Lab Failed: Not all pods are running (expected: 5, found: X)
```

---

### Test Case 4: No Pods in Error States
**Purpose:** Verify no pods are in ImagePullBackOff, CrashLoopBackOff, or Error states

**Test Logic:**
```bash
ERROR_PODS=$(kubectl get pods -n retailpulse-prod -l app=analytics-engine --no-headers 2>/dev/null | grep -E "ImagePullBackOff|CrashLoopBackOff|Error|ErrImagePull" | wc -l)

if [ "$ERROR_PODS" -gt 0 ]; then
    exit 1
fi
```

**Success Criteria:**
- No pods in error states

**Failure Message:**
```
Lab Failed: Some pods are still in error states (ImagePullBackOff, CrashLoopBackOff, etc.)
```

---

### Test Case 5: No Pending Pods
**Purpose:** Verify no pods are stuck in Pending state (scheduling failure)

**Test Logic:**
```bash
PENDING_PODS=$(kubectl get pods -n retailpulse-prod -l app=analytics-engine --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)

if [ "$PENDING_PODS" -gt 0 ]; then
    exit 1
fi
```

**Success Criteria:**
- No pods in Pending state

**Failure Message:**
```
Lab Failed: Some pods are still in Pending state - check for scheduling issues (taints, node selectors, resources)
```

---

### Test Case 6: Correct Image Name
**Purpose:** Verify image name is corrected (no typo)

**Test Logic:**
```bash
IMAGE=$(kubectl get deployment analytics-engine -n retailpulse-prod -o jsonpath='{.spec.template.spec.containers[0].image}')

if [ "$IMAGE" != "retailpulse/analytics-engine:v2.4" ]; then
    exit 1
fi
```

**Success Criteria:**
- Image is exactly `retailpulse/analytics-engine:v2.4`

**Failure Message:**
```
Lab Failed: Image name is incorrect. Expected 'retailpulse/analytics-engine:v2.4', found 'X'
```

---

### Test Case 7: Toleration Present
**Purpose:** Verify toleration for tainted node is added

**Test Logic:**
```bash
TOLERATION=$(kubectl get deployment analytics-engine -n retailpulse-prod -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="workload")].key}')

if [ "$TOLERATION" != "workload" ]; then
    exit 1
fi

TOLERATION_VALUE=$(kubectl get deployment analytics-engine -n retailpulse-prod -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="workload")].value}')

if [ "$TOLERATION_VALUE" != "analytics" ]; then
    exit 1
fi
```

**Success Criteria:**
- Toleration with key `workload` and value `analytics` exists

**Failure Message:**
```
Lab Failed: Missing or incorrect toleration for taint 'workload=analytics:NoSchedule'
```

---

### Test Case 8: CPU Request Adequate
**Purpose:** Verify CPU request is at least 100m

**Test Logic:**
```bash
CPU_REQUEST=$(kubectl get deployment analytics-engine -n retailpulse-prod -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')

# Convert to millicores for comparison
CPU_MILLI=$(echo "$CPU_REQUEST" | sed 's/m//')

if [ "$CPU_MILLI" -lt 100 ]; then
    exit 1
fi
```

**Success Criteria:**
- CPU request is >= 100m

**Failure Message:**
```
Lab Failed: CPU request is too low (found: X, minimum required: 100m)
```

---

### Test Case 9: Image Pull Policy Fixed
**Purpose:** Verify image pull policy is not set to Never

**Test Logic:**
```bash
PULL_POLICY=$(kubectl get deployment analytics-engine -n retailpulse-prod -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}')

if [ "$PULL_POLICY" == "Never" ]; then
    exit 1
fi
```

**Success Criteria:**
- Image pull policy is `IfNotPresent` or `Always` (not `Never`)

**Failure Message:**
```
Lab Failed: Image pull policy is set to 'Never' which prevents pulling from registry
```

---

### Test Case 10: Pod Scheduled on Tainted Node
**Purpose:** Verify at least one pod is scheduled on the tainted node

**Test Logic:**
```bash
# Get the tainted node name
TAINTED_NODE=$(kubectl get nodes -o json | jq -r '.items[] | select(.spec.taints[]? | select(.key=="workload" and .value=="analytics")) | .metadata.name')

if [ -z "$TAINTED_NODE" ]; then
    echo "Warning: No tainted node found in cluster"
    exit 0
fi

# Check if any pod is on the tainted node
PODS_ON_TAINTED=$(kubectl get pods -n retailpulse-prod -l app=analytics-engine -o wide --no-headers | grep "$TAINTED_NODE" | wc -l)

if [ "$PODS_ON_TAINTED" -eq 0 ]; then
    exit 1
fi
```

**Success Criteria:**
- At least one pod is running on the node with taint `workload=analytics`

**Failure Message:**
```
Lab Failed: No pods scheduled on tainted node - toleration may not be working correctly
```

---

### Test Case 11: Deployment Available
**Purpose:** Verify deployment shows 5/5 available replicas

**Test Logic:**
```bash
AVAILABLE=$(kubectl get deployment analytics-engine -n retailpulse-prod -o jsonpath='{.status.availableReplicas}')

if [ "$AVAILABLE" != "5" ]; then
    exit 1
fi
```

**Success Criteria:**
- Deployment status shows 5 available replicas

**Failure Message:**
```
Lab Failed: Deployment does not have 5 available replicas (found: X)
```

---

### Test Case 12: No Recent Restarts
**Purpose:** Verify pods are stable (no crash loops)

**Test Logic:**
```bash
MAX_RESTARTS=0

for pod in $(kubectl get pods -n retailpulse-prod -l app=analytics-engine -o jsonpath='{.items[*].metadata.name}'); do
    RESTARTS=$(kubectl get pod $pod -n retailpulse-prod -o jsonpath='{.status.containerStatuses[0].restartCount}')
    if [ "$RESTARTS" -gt "$MAX_RESTARTS" ]; then
        MAX_RESTARTS=$RESTARTS
    fi
done

if [ "$MAX_RESTARTS" -gt 2 ]; then
    exit 1
fi
```

**Success Criteria:**
- No pod has more than 2 restarts

**Failure Message:**
```
Lab Failed: Pods have excessive restarts indicating instability
```

---

### Test Case 13: Node Selector Removed or Fixed
**Purpose:** Verify invalid node selector is not preventing scheduling

**Test Logic:**
```bash
NODE_SELECTOR=$(kubectl get deployment analytics-engine -n retailpulse-prod -o jsonpath='{.spec.template.spec.nodeSelector}')

# If node selector exists and includes 'environment: production', check if nodes have this label
if echo "$NODE_SELECTOR" | grep -q "production"; then
    NODES_WITH_LABEL=$(kubectl get nodes -l environment=production --no-headers 2>/dev/null | wc -l)
    if [ "$NODES_WITH_LABEL" -eq 0 ]; then
        exit 1
    fi
fi
```

**Success Criteria:**
- Either no node selector, or node selector points to labels that exist on nodes

**Failure Message:**
```
Lab Failed: Node selector references labels that don't exist on any nodes
```

---

### Complete Test Script

```bash
#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

# Variables
NAMESPACE="retailpulse-prod"
DEPLOYMENT_NAME="analytics-engine"
EXPECTED_REPLICAS=5
EXPECTED_IMAGE="retailpulse/analytics-engine:v2.4"
MIN_CPU_REQUEST=100

# Test Case 1: Namespace and Deployment Existence
function test_deployment_exists() {
    if ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: Deployment '$DEPLOYMENT_NAME' does not exist in namespace '$NAMESPACE'"
        exit 1
    fi
    print_status "success" "Lab Passed: Deployment exists"
}

# Test Case 2: Replica Count Check
function test_replica_count() {
    REPLICAS=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
    
    if [ "$REPLICAS" != "$EXPECTED_REPLICAS" ]; then
        print_status "failed" "Lab Failed: Deployment does not have $EXPECTED_REPLICAS replicas (found: $REPLICAS)"
        exit 1
    fi
    print_status "success" "Lab Passed: Correct replica count"
}

# Test Case 3: All Pods Running
function test_pods_running() {
    for i in {1..120}; do
        RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=analytics-engine --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        if [ "$RUNNING_PODS" -eq "$EXPECTED_REPLICAS" ]; then
            print_status "success" "Lab Passed: All pods are running"
            return 0
        fi
        sleep 1
    done
    
    RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=analytics-engine --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    print_status "failed" "Lab Failed: Not all pods are running (expected: $EXPECTED_REPLICAS, found: $RUNNING_PODS)"
    exit 1
}

# Test Case 4: No Pods in Error States
function test_no_error_pods() {
    ERROR_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=analytics-engine --no-headers 2>/dev/null | grep -E "ImagePullBackOff|CrashLoopBackOff|Error|ErrImagePull" | wc -l)
    
    if [ "$ERROR_PODS" -gt 0 ]; then
        print_status "failed" "Lab Failed: Some pods are in error states"
        exit 1
    fi
    print_status "success" "Lab Passed: No pods in error states"
}

# Test Case 5: No Pending Pods
function test_no_pending_pods() {
    PENDING_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=analytics-engine --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
    
    if [ "$PENDING_PODS" -gt 0 ]; then
        print_status "failed" "Lab Failed: Some pods are in Pending state"
        exit 1
    fi
    print_status "success" "Lab Passed: No pending pods"
}

# Test Case 6: Correct Image Name
function test_image_name() {
    IMAGE=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')
    
    if [ "$IMAGE" != "$EXPECTED_IMAGE" ]; then
        print_status "failed" "Lab Failed: Image name is incorrect (expected: $EXPECTED_IMAGE, found: $IMAGE)"
        exit 1
    fi
    print_status "success" "Lab Passed: Correct image name"
}

# Test Case 7: Toleration Present
function test_toleration() {
    TOLERATION=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="workload")].key}')
    
    if [ "$TOLERATION" != "workload" ]; then
        print_status "failed" "Lab Failed: Missing toleration for taint 'workload=analytics'"
        exit 1
    fi
    
    TOLERATION_VALUE=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.tolerations[?(@.key=="workload")].value}')
    
    if [ "$TOLERATION_VALUE" != "analytics" ]; then
        print_status "failed" "Lab Failed: Incorrect toleration value"
        exit 1
    fi
    
    print_status "success" "Lab Passed: Correct toleration configured"
}

# Test Case 8: CPU Request Adequate
function test_cpu_request() {
    CPU_REQUEST=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
    
    CPU_MILLI=$(echo "$CPU_REQUEST" | sed 's/m//')
    
    if [ "$CPU_MILLI" -lt "$MIN_CPU_REQUEST" ]; then
        print_status "failed" "Lab Failed: CPU request too low (found: $CPU_REQUEST, minimum: ${MIN_CPU_REQUEST}m)"
        exit 1
    fi
    print_status "success" "Lab Passed: Adequate CPU request"
}

# Test Case 9: Image Pull Policy Fixed
function test_image_pull_policy() {
    PULL_POLICY=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}')
    
    if [ "$PULL_POLICY" == "Never" ]; then
        print_status "failed" "Lab Failed: Image pull policy is 'Never'"
        exit 1
    fi
    print_status "success" "Lab Passed: Image pull policy is correct"
}

# Test Case 10: Pod Scheduled on Tainted Node
function test_pod_on_tainted_node() {
    TAINTED_NODE=$(kubectl get nodes -o json 2>/dev/null | jq -r '.items[] | select(.spec.taints[]? | select(.key=="workload" and .value=="analytics")) | .metadata.name' | head -1)
    
    if [ -z "$TAINTED_NODE" ]; then
        print_status "success" "Lab Passed: No tainted node to test (skipped)"
        return 0
    fi
    
    PODS_ON_TAINTED=$(kubectl get pods -n "$NAMESPACE" -l app=analytics-engine -o wide --no-headers 2>/dev/null | grep "$TAINTED_NODE" | wc -l)
    
    if [ "$PODS_ON_TAINTED" -eq 0 ]; then
        print_status "failed" "Lab Failed: No pods scheduled on tainted node"
        exit 1
    fi
    print_status "success" "Lab Passed: Pod(s) scheduled on tainted node"
}

# Test Case 11: Deployment Available
function test_deployment_available() {
    AVAILABLE=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.status.availableReplicas}')
    
    if [ "$AVAILABLE" != "$EXPECTED_REPLICAS" ]; then
        print_status "failed" "Lab Failed: Not all replicas available (found: $AVAILABLE)"
        exit 1
    fi
    print_status "success" "Lab Passed: All replicas available"
}

# Test Case 12: No Recent Restarts
function test_no_restarts() {
    MAX_RESTARTS=0
    
    for pod in $(kubectl get pods -n "$NAMESPACE" -l app=analytics-engine -o jsonpath='{.items[*].metadata.name}'); do
        RESTARTS=$(kubectl get pod $pod -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}')
        if [ "$RESTARTS" -gt "$MAX_RESTARTS" ]; then
            MAX_RESTARTS=$RESTARTS
        fi
    done
    
    if [ "$MAX_RESTARTS" -gt 2 ]; then
        print_status "failed" "Lab Failed: Pods have excessive restarts ($MAX_RESTARTS)"
        exit 1
    fi
    print_status "success" "Lab Passed: Pods are stable"
}

# Execute all tests
test_deployment_exists
test_replica_count
test_pods_running
test_no_error_pods
test_no_pending_pods
test_image_name
test_toleration
test_cpu_request
test_image_pull_policy
test_pod_on_tainted_node
test_deployment_available
test_no_restarts

exit 0
```

---

## Section 10: Setup Script

### Pre-Lab Environment Setup

**What needs to be configured before student starts:**
- Kubernetes cluster with 3 worker nodes
- One node with taint `workload=analytics:NoSchedule`
- Namespace `retailpulse-prod` created
- Broken deployment applied with all 5 mistakes
- No other conflicting resources

### Setup Script

```bash
#!/bin/bash

set -euo pipefail

# Variables
NAMESPACE="retailpulse-prod"
DEPLOYMENT_NAME="analytics-engine"
TAINTED_NODE=""

echo "Starting lab environment setup for Kubernetes Troubleshooting..."

# Function: Get a worker node to taint
function setup_tainted_node() {
    echo "Setting up tainted node..."
    
    # Get first worker node
    TAINTED_NODE=$(kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$TAINTED_NODE" ]; then
        echo "ERROR: No worker nodes found"
        exit 1
    fi
    
    echo "Selected node for tainting: $TAINTED_NODE"
    
    # Remove taint if it exists (cleanup)
    kubectl taint nodes "$TAINTED_NODE" workload=analytics:NoSchedule- 2>/dev/null || true
    
    # Add taint
    kubectl taint nodes "$TAINTED_NODE" workload=analytics:NoSchedule
    
    echo "Taint applied to node: $TAINTED_NODE"
}

# Function: Clean up any existing resources
function cleanup_existing_resources() {
    echo "Cleaning up existing lab resources..."
    
    # Delete deployment if exists
    if kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &>/dev/null; then
        echo "Deleting existing deployment"
        kubectl delete deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --ignore-not-found=true
    fi
    
    # Delete namespace if exists
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo "Deleting existing namespace"
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true --timeout=60s
        
        # Wait for namespace deletion
        for i in {1..30}; do
            if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
                break
            fi
            sleep 2
        done
    fi
    
    echo "Cleanup completed"
}

# Function: Create namespace
function create_namespace() {
    echo "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
    echo "Namespace created"
}

# Function: Deploy broken deployment with 5 mistakes
function deploy_broken_deployment() {
    echo "Deploying broken analytics-engine with intentional mistakes..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analytics-engine
  namespace: retailpulse-prod
  labels:
    app: analytics-engine
spec:
  replicas: 5
  selector:
    matchLabels:
      app: analytics-engine
  template:
    metadata:
      labels:
        app: analytics-engine
    spec:
      # MISTAKE #3: Invalid node selector
      nodeSelector:
        environment: production
      
      # MISTAKE #2: Missing toleration for tainted node
      # tolerations section completely missing
      
      containers:
      - name: analytics
        # MISTAKE #1: Typo in image name
        image: retailpulse/analytics-enigne:v2.4
        
        # MISTAKE #5: Wrong image pull policy
        imagePullPolicy: Never
        
        ports:
        - containerPort: 8080
        
        resources:
          requests:
            # MISTAKE #4: CPU request too low
            cpu: 10m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        
        env:
        - name: LOG_LEVEL
          value: info
EOF
    
    echo "Broken deployment created with 5 intentional mistakes"
}

# Function: Verify setup
function verify_setup() {
    echo "Verifying lab setup..."
    
    # Check namespace exists
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo "ERROR: Namespace not created"
        exit 1
    fi
    
    # Check deployment exists
    if ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &>/dev/null; then
        echo "ERROR: Deployment not created"
        exit 1
    fi
    
    # Check tainted node exists
    TAINT_CHECK=$(kubectl get nodes "$TAINTED_NODE" -o jsonpath='{.spec.taints[?(@.key=="workload")].key}')
    if [ "$TAINT_CHECK" != "workload" ]; then
        echo "ERROR: Taint not applied correctly"
        exit 1
    fi
    
    # Wait a bit for pods to start failing
    echo "Waiting 30 seconds for pods to reach error states..."
    sleep 30
    
    # Check that pods are NOT all running (they should be in error states)
    RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=analytics-engine --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    
    if [ "$RUNNING_PODS" -eq 5 ]; then
        echo "WARNING: All pods are running - mistakes may not be configured correctly"
    else
        echo "Good: Pods are in error states as expected"
    fi
    
    # Show pod status
    echo ""
    echo "Current pod status (should show errors):"
    kubectl get pods -n "$NAMESPACE"
    
    echo ""
    echo "Lab setup verification completed successfully"
}

# Execute setup
cleanup_existing_resources
setup_tainted_node
create_namespace
deploy_broken_deployment
verify_setup

echo ""
echo "================================================================"
echo "Lab environment is ready!"
echo "================================================================"
echo "Namespace: $NAMESPACE"
echo "Deployment: $DEPLOYMENT_NAME (with 5 intentional mistakes)"
echo "Tainted Node: $TAINTED_NODE (taint: workload=analytics:NoSchedule)"
echo ""
echo "Students should now:"
echo "1. Investigate why pods are failing"
echo "2. Identify all 5 configuration mistakes"
echo "3. Fix the deployment"
echo "4. Verify all 5 pods are running successfully"
echo "================================================================"
```

### Setup Verification

**After running setup script, verify:**
```bash
# Check 1: Namespace exists
kubectl get namespace retailpulse-prod

# Check 2: Deployment exists
kubectl get deployment analytics-engine -n retailpulse-prod

# Check 3: Pods are NOT all running (they should be in error states)
kubectl get pods -n retailpulse-prod

# Check 4: Tainted node exists
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Expected: One node should show taint workload=analytics:NoSchedule
```

**Expected Initial State (after setup):**
- 5 pods exist but are NOT running
- Some pods in ImagePullBackOff state
- Some pods in Pending state
- Deployment shows 0/5 available replicas

---

**Template Version:** 1.0  
**Last Updated:** December 2024