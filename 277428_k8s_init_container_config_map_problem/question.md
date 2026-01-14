# Lab Question Template

## Template Metadata

**Difficulty Level:** HARD

**Format Type:** Assignment

**Scenario-Based:** Yes

**Estimated Time:** 60 minutes

**Technology/Topic:** Kubernetes

---

## Section 1: Story/Context

### Company Background
- **Company Name:** TechFlow Solutions
- **Industry:** Fintech (Payment Processing)
- **Scale:** Mid-size startup
- **Core Business:** Provides payment processing services to e-commerce businesses, handling thousands of transactions per minute

### The Incident/Problem
- **What happened:** Payment gateway service experienced a major production outage during a routine deployment
- **When it occurred:** Last week during regular business hours
- **Impact on business:** 45-minute downtime resulting in approximately $50,000 in lost transaction fees and significant damage to client trust
- **Symptoms observed:**
  * Multiple pods crashing immediately after deployment
  * Application throwing configuration errors on startup
  * Payment transactions failing across all clients
  * Emergency rollback required to restore service

### Root Cause Analysis
- **Primary cause:** Application containers started before ConfigMap volumes were fully mounted, causing the application to crash when trying to read missing configuration files
- **Contributing factors:**
  * No validation mechanism to verify configuration was loaded before application startup
  * Application had poor error handling for missing configuration
  * No pre-flight checks in the deployment pipeline
  * Development and production environments had different mounting behavior
- **Why it matters:** Payment processing requires 99.9% uptime SLA. Configuration-related failures are preventable with proper validation patterns

### Your Mission
- **Your role:** Senior DevOps Engineer
- **Who assigned it:** CTO has mandated this fix after the incident review
- **What you need to accomplish:** Implement an init container pattern that validates ConfigMap is properly loaded and contains all required keys before allowing the payment gateway to start
- **Success criteria:** Pods must never reach running state if configuration is missing or invalid. Solution must be testable and fail safely in all scenarios

---

## Section 2: Task Description

### Lab Environment Setup
**Provided Resources:**
- Kubernetes cluster (pre-configured)
- kubectl CLI access
- Namespace creation permissions

**Credentials/Access:**
```
All kubectl commands will work directly in the provided environment
No additional credentials required
```

### Tasks Breakdown

**Task 1: Create Production Namespace**
- Objective: Isolate payment gateway deployment in dedicated namespace
- Steps required:
  1. Create namespace named `techflow-prod`
  2. Verify namespace was created successfully
- Expected outcome: Namespace `techflow-prod` exists and is active

**Task 2: Create Payment Gateway Configuration**
- Objective: Define all required configuration for the payment gateway service
- Steps required:
  1. Create a ConfigMap named `gateway-config` in `techflow-prod` namespace
  2. Add configuration file with key `gateway.conf`
  3. Include all six required configuration parameters:
     - SERVICE_NAME=payment-gateway
     - SERVICE_VERSION=3.2.1
     - DATABASE_URL=postgres://payments-db.techflow-prod.svc.cluster.local:5432/payments
     - REDIS_URL=redis://cache.techflow-prod.svc.cluster.local:6379
     - MAX_CONNECTIONS=100
     - TIMEOUT_SECONDS=30
- Expected outcome: ConfigMap contains all required configuration parameters in correct format

**Task 3: Deploy Payment Gateway with Init Container Validation**
- Objective: Create deployment with init container that validates configuration before main application starts
- Steps required:
  1. Create deployment named `payment-gateway` in `techflow-prod` namespace
  2. Configure 3 replicas for high availability
  3. Add init container named `config-guardian` that:
     - Mounts ConfigMap at `/config/gateway.conf`
     - Validates file exists
     - Validates all 6 required keys are present
     - Exits with code 0 only if all validations pass
     - Provides clear log messages for each validation step
  4. Add main container named `gateway` that:
     - Uses image `nginx:alpine`
     - Mounts same ConfigMap at `/etc/techflow/gateway.conf`
     - Exposes port 8080
  5. Configure resource limits:
     - Init container: 50m CPU, 64Mi memory (requests and limits)
     - Main container: 200m CPU, 256Mi memory (requests), 500m CPU, 512Mi memory (limits)
  6. Add appropriate labels: `app=payment-gateway`, `tier=critical`, `team=payments`
- Expected outcome: Deployment creates 3 pods that only reach Running state after init container successfully validates configuration

**Task 4: Verify Deployment Success**
- Objective: Confirm all pods are running and configuration is properly validated
- Steps required:
  1. Check all 3 pods reach Running state
  2. Verify init container logs show successful validation
  3. Confirm main container has access to configuration file
- Expected outcome: All pods running, init container logs show validation success, configuration accessible in main container

**Task 5: Test Failure Scenarios**
- Objective: Prove the solution prevents bad deployments
- Steps required:
  1. Test Scenario A: Delete ConfigMap and attempt to scale new pods
  2. Test Scenario B: Create ConfigMap missing DATABASE_URL key and trigger rollout
  3. Document pod behavior in each failure case
- Expected outcome: Pods fail to start in both scenarios, with clear error messages in init container logs

### Verification Requirements
**You must verify:**
- Namespace `techflow-prod` exists
- ConfigMap `gateway-config` contains all 6 required parameters
- Deployment `payment-gateway` is created with 3 replicas
- All pods reach Running state with 1/1 containers ready
- Init container logs show successful validation messages
- Configuration file is accessible in main container at `/etc/techflow/gateway.conf`
- Pods fail safely when ConfigMap is missing or incomplete

---

## Section 3: Learning Outcomes

After completing this lab, you will be able to:
- Implement init containers as validation gates for application dependencies
- Create and mount ConfigMaps in Kubernetes deployments
- Share volumes between init containers and main application containers
- Design fail-fast deployment patterns that prevent broken pods from starting
- Write validation scripts that provide clear, actionable error messages
- Configure appropriate resource requests and limits for different container types
- Test deployment resilience through controlled failure scenarios
- Understand container startup sequencing and dependencies

**Key Concepts Covered:**
- Init containers and their use in validation workflows
- ConfigMap creation and volume mounting
- Container resource management (requests vs limits)
- Deployment rollout behavior and safety mechanisms
- Volume sharing between containers in the same pod
- Exit codes and their impact on pod lifecycle
- Kubernetes pod startup phases and readiness

---

## Section 4: Hints and Tips

**Common Pitfalls to Avoid:**
- Forgetting to set `create_home: false` in user module can cause unexpected directory creation
- Using different mount paths in init container vs main container will cause main container to not find the config
- Not setting `remove: true` when deleting users means home directories persist
- Init container validation script must use proper exit codes (0 for success, non-zero for failure)
- Resource limits must be equal to or greater than requests

**Helpful Commands:**
```bash
# Check pod status and which containers are running
kubectl get pods -n techflow-prod

# View init container logs
kubectl logs <pod-name> -n techflow-prod -c config-guardian

# View main container logs
kubectl logs <pod-name> -n techflow-prod -c gateway

# Describe pod to see events and why it might be failing
kubectl describe pod <pod-name> -n techflow-prod

# Check ConfigMap contents
kubectl get configmap gateway-config -n techflow-prod -o yaml

# Execute command inside running container to verify file
kubectl exec <pod-name> -n techflow-prod -c gateway -- cat /etc/techflow/gateway.conf
```

**Documentation References:**
- [Kubernetes Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [ConfigMaps Documentation](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Resource Management for Pods](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

---

## Section 5: Evaluation Criteria

### Deliverables Required:

**Configuration Files/Scripts**
- Namespace YAML or kubectl command creating `techflow-prod` namespace
- ConfigMap YAML containing all required gateway configuration parameters
- Deployment YAML with init container validation and main application container

### Auto-Evaluation Criteria

Your solution will be automatically evaluated based on:

- Namespace `techflow-prod` exists in the cluster
- ConfigMap `gateway-config` exists with correct data key and all 6 required parameters
- Deployment `payment-gateway` exists with correct name and namespace
- Deployment has exactly 3 replicas configured
- Init container named `config-guardian` is present in pod spec
- Init container mounts ConfigMap volume at `/config/gateway.conf`
- Main container named `gateway` is present in pod spec
- Main container mounts ConfigMap volume at `/etc/techflow/gateway.conf`
- Resource requests and limits are set correctly on both containers
- All pods reach Running state with 1/1 ready status
- Init container successfully validates configuration (visible in logs)
- When ConfigMap is deleted, new pods fail to start (init container fails)
- When ConfigMap is missing required keys, new pods fail to start (init container fails)

---

## Section 6: Expected Time Breakdown

| Task | Estimated Time |
|------|----------------|
| Create namespace | 2 minutes |
| Create ConfigMap | 5 minutes |
| Write deployment YAML with init container | 20 minutes |
| Apply deployment and troubleshoot | 15 minutes |
| Verify successful deployment | 8 minutes |
| Test failure scenarios | 10 minutes |
| **Total** | **60 minutes** |

---

## Section 7: Technical Specifications

**Technology Stack:**
- Kubernetes - v1.28+

**Environment Details:**
- OS: Linux (kubectl client)
- Pre-installed tools: kubectl, text editor (vi/nano)
- Network configuration: Standard Kubernetes cluster networking

**File Locations:**
- Working directory: `/home/user` or any directory of your choice
- ConfigMap mount in init container: `/config/gateway.conf`
- ConfigMap mount in main container: `/etc/techflow/gateway.conf`

---

## Section 8: Ideal Solution

### Solution Overview
The solution involves creating a three-part Kubernetes deployment: namespace isolation, ConfigMap with required parameters, and a deployment with an init container that validates the ConfigMap before allowing the main application to start. The init container acts as a gatekeeper, ensuring configuration integrity before the payment gateway launches.

### Step-by-Step Solution

**Step 1: Create the Production Namespace**
```bash
# Create namespace for payment gateway
kubectl create namespace techflow-prod
```

**Expected Output:**
```
namespace/techflow-prod created
```

**Step 2: Create the ConfigMap with Gateway Configuration**
```bash
# Create ConfigMap with all required parameters
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gateway-config
  namespace: techflow-prod
data:
  gateway.conf: |
    SERVICE_NAME=payment-gateway
    SERVICE_VERSION=3.2.1
    DATABASE_URL=postgres://payments-db.techflow-prod.svc.cluster.local:5432/payments
    REDIS_URL=redis://cache.techflow-prod.svc.cluster.local:6379
    MAX_CONNECTIONS=100
    TIMEOUT_SECONDS=30
EOF
```

**Expected Output:**
```
configmap/gateway-config created
```

**Step 3: Create the Deployment with Init Container Validation**
```bash
# Create deployment with init container and main container
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-gateway
  namespace: techflow-prod
  labels:
    app: payment-gateway
    tier: critical
    team: payments
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-gateway
  template:
    metadata:
      labels:
        app: payment-gateway
        tier: critical
        team: payments
    spec:
      initContainers:
      - name: config-guardian
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          echo "TechFlow Payment Gateway - Configuration Guardian"
          echo "=================================================="
          echo "Starting pre-flight configuration validation..."
          echo ""
          
          CONFIG_FILE="/config/gateway.conf"
          
          echo "[CHECK 1/2] Verifying configuration file exists..."
          if [ ! -f "\$CONFIG_FILE" ]; then
              echo "FATAL: Configuration file not found at \$CONFIG_FILE"
              echo "DEPLOYMENT BLOCKED: Cannot start payment gateway without configuration"
              exit 1
          fi
          echo "Configuration file found"
          echo ""
          
          echo "[CHECK 2/2] Validating required configuration parameters..."
          REQUIRED_KEYS="SERVICE_NAME SERVICE_VERSION DATABASE_URL REDIS_URL MAX_CONNECTIONS TIMEOUT_SECONDS"
          VALIDATION_FAILED=0
          
          for key in \$REQUIRED_KEYS; do
              if grep -q "^\${key}=" "\$CONFIG_FILE"; then
                  VALUE=\$(grep "^\${key}=" "\$CONFIG_FILE" | cut -d'=' -f2)
                  echo "  \$key = \$VALUE"
              else
                  echo "  MISSING: \$key"
                  VALIDATION_FAILED=1
              fi
          done
          
          echo ""
          if [ \$VALIDATION_FAILED -eq 1 ]; then
              echo "VALIDATION FAILED: Missing required configuration parameters"
              echo "DEPLOYMENT BLOCKED: Fix configuration and try again"
              exit 1
          fi
          
          echo "All configuration parameters validated successfully"
          echo "=================================================="
          echo "Payment gateway is cleared for startup"
          exit 0
        volumeMounts:
        - name: config-volume
          mountPath: /config
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 50m
            memory: 64Mi
      containers:
      - name: gateway
        image: nginx:alpine
        ports:
        - containerPort: 8080
        env:
        - name: ENV
          value: production
        - name: LOG_LEVEL
          value: info
        volumeMounts:
        - name: config-volume
          mountPath: /etc/techflow
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: config-volume
        configMap:
          name: gateway-config
EOF
```

**Expected Output:**
```
deployment.apps/payment-gateway created
```

**Step 4: Verify Deployment Success**
```bash
# Check deployment status
kubectl get deployment payment-gateway -n techflow-prod
```

**Expected Output:**
```
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
payment-gateway   3/3     3            3           30s
```

**Step 5: Verify Pods are Running**
```bash
# Check all pods are running
kubectl get pods -n techflow-prod
```

**Expected Output:**
```
NAME                               READY   STATUS    RESTARTS   AGE
payment-gateway-7d4f8b9c5d-abc12   1/1     Running   0          45s
payment-gateway-7d4f8b9c5d-def34   1/1     Running   0          45s
payment-gateway-7d4f8b9c5d-ghi56   1/1     Running   0          45s
```

### Verification Commands

**Verify init container validation logs:**
```bash
# Get first pod name
POD_NAME=$(kubectl get pods -n techflow-prod -l app=payment-gateway -o jsonpath='{.items[0].metadata.name}')

# View init container logs
kubectl logs $POD_NAME -n techflow-prod -c config-guardian
```

**Expected Output:**
```
TechFlow Payment Gateway - Configuration Guardian
==================================================
Starting pre-flight configuration validation...

[CHECK 1/2] Verifying configuration file exists...
Configuration file found

[CHECK 2/2] Validating required configuration parameters...
  SERVICE_NAME = payment-gateway
  SERVICE_VERSION = 3.2.1
  DATABASE_URL = postgres://payments-db.techflow-prod.svc.cluster.local:5432/payments
  REDIS_URL = redis://cache.techflow-prod.svc.cluster.local:6379
  MAX_CONNECTIONS = 100
  TIMEOUT_SECONDS = 30

All configuration parameters validated successfully
==================================================
Payment gateway is cleared for startup
```

**Verify configuration accessible in main container:**
```bash
# Execute cat command inside main container
kubectl exec $POD_NAME -n techflow-prod -c gateway -- cat /etc/techflow/gateway.conf
```

**Expected Output:**
```
SERVICE_NAME=payment-gateway
SERVICE_VERSION=3.2.1
DATABASE_URL=postgres://payments-db.techflow-prod.svc.cluster.local:5432/payments
REDIS_URL=redis://cache.techflow-prod.svc.cluster.local:6379
MAX_CONNECTIONS=100
TIMEOUT_SECONDS=30
```

**Verify resource limits are set:**
```bash
kubectl get pod $POD_NAME -n techflow-prod -o jsonpath='{.spec.initContainers[0].resources}' | jq
kubectl get pod $POD_NAME -n techflow-prod -o jsonpath='{.spec.containers[0].resources}' | jq
```

**Expected Output:**
```
{
  "limits": {
    "cpu": "50m",
    "memory": "64Mi"
  },
  "requests": {
    "cpu": "50m",
    "memory": "64Mi"
  }
}
{
  "limits": {
    "cpu": "500m",
    "memory": "512Mi"
  },
  "requests": {
    "cpu": "200m",
    "memory": "256Mi"
  }
}
```

### Test Failure Scenarios

**Test Scenario A: Missing ConfigMap**
```bash
# Delete the ConfigMap
kubectl delete configmap gateway-config -n techflow-prod

# Try to scale up (create new pod)
kubectl scale deployment payment-gateway -n techflow-prod --replicas=4

# Watch pods - the 4th pod should fail
kubectl get pods -n techflow-prod -w
```

**Expected Behavior:**
New pod will be stuck in Init:Error or Init:CrashLoopBackOff state

**Check init container logs of failing pod:**
```bash
# Get the failing pod name
FAILING_POD=$(kubectl get pods -n techflow-prod | grep Init | awk '{print $1}')

# View logs
kubectl logs $FAILING_POD -n techflow-prod -c config-guardian
```

**Expected Output:**
```
TechFlow Payment Gateway - Configuration Guardian
==================================================
Starting pre-flight configuration validation...

[CHECK 1/2] Verifying configuration file exists...
FATAL: Configuration file not found at /config/gateway.conf
DEPLOYMENT BLOCKED: Cannot start payment gateway without configuration
```

**Restore ConfigMap:**
```bash
# Recreate the ConfigMap
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gateway-config
  namespace: techflow-prod
data:
  gateway.conf: |
    SERVICE_NAME=payment-gateway
    SERVICE_VERSION=3.2.1
    DATABASE_URL=postgres://payments-db.techflow-prod.svc.cluster.local:5432/payments
    REDIS_URL=redis://cache.techflow-prod.svc.cluster.local:6379
    MAX_CONNECTIONS=100
    TIMEOUT_SECONDS=30
EOF
```

**Test Scenario B: Incomplete ConfigMap**
```bash
# Create ConfigMap with missing DATABASE_URL
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gateway-config
  namespace: techflow-prod
data:
  gateway.conf: |
    SERVICE_NAME=payment-gateway
    SERVICE_VERSION=3.2.1
    REDIS_URL=redis://cache.techflow-prod.svc.cluster.local:6379
    MAX_CONNECTIONS=100
    TIMEOUT_SECONDS=30
EOF

# Trigger a rollout
kubectl rollout restart deployment payment-gateway -n techflow-prod

# Watch the rollout fail
kubectl get pods -n techflow-prod -w
```

**Expected Behavior:**
New pods will fail in Init state, old pods remain running (deployment strategy protects availability)

**Check init container logs:**
```bash
# Get one of the failing pods
FAILING_POD=$(kubectl get pods -n techflow-prod | grep Init | head -1 | awk '{print $1}')

kubectl logs $FAILING_POD -n techflow-prod -c config-guardian
```

**Expected Output:**
```
TechFlow Payment Gateway - Configuration Guardian
==================================================
Starting pre-flight configuration validation...

[CHECK 1/2] Verifying configuration file exists...
Configuration file found

[CHECK 2/2] Validating required configuration parameters...
  SERVICE_NAME = payment-gateway
  SERVICE_VERSION = 3.2.1
  MISSING: DATABASE_URL
  REDIS_URL = redis://cache.techflow-prod.svc.cluster.local:6379
  MAX_CONNECTIONS = 100
  TIMEOUT_SECONDS = 30

VALIDATION FAILED: Missing required configuration parameters
DEPLOYMENT BLOCKED: Fix configuration and try again
```

### Complete Solution Files

**namespace.yaml:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: techflow-prod
```

**configmap.yaml:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gateway-config
  namespace: techflow-prod
data:
  gateway.conf: |
    SERVICE_NAME=payment-gateway
    SERVICE_VERSION=3.2.1
    DATABASE_URL=postgres://payments-db.techflow-prod.svc.cluster.local:5432/payments
    REDIS_URL=redis://cache.techflow-prod.svc.cluster.local:6379
    MAX_CONNECTIONS=100
    TIMEOUT_SECONDS=30
```

**deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-gateway
  namespace: techflow-prod
  labels:
    app: payment-gateway
    tier: critical
    team: payments
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-gateway
  template:
    metadata:
      labels:
        app: payment-gateway
        tier: critical
        team: payments
    spec:
      initContainers:
      - name: config-guardian
        image: busybox:latest
        command:
        - sh
        - -c
        - |
          echo "TechFlow Payment Gateway - Configuration Guardian"
          echo "=================================================="
          echo "Starting pre-flight configuration validation..."
          echo ""
          
          CONFIG_FILE="/config/gateway.conf"
          
          echo "[CHECK 1/2] Verifying configuration file exists..."
          if [ ! -f "$CONFIG_FILE" ]; then
              echo "FATAL: Configuration file not found at $CONFIG_FILE"
              echo "DEPLOYMENT BLOCKED: Cannot start payment gateway without configuration"
              exit 1
          fi
          echo "Configuration file found"
          echo ""
          
          echo "[CHECK 2/2] Validating required configuration parameters..."
          REQUIRED_KEYS="SERVICE_NAME SERVICE_VERSION DATABASE_URL REDIS_URL MAX_CONNECTIONS TIMEOUT_SECONDS"
          VALIDATION_FAILED=0
          
          for key in $REQUIRED_KEYS; do
              if grep -q "^${key}=" "$CONFIG_FILE"; then
                  VALUE=$(grep "^${key}=" "$CONFIG_FILE" | cut -d'=' -f2)
                  echo "  $key = $VALUE"
              else
                  echo "  MISSING: $key"
                  VALIDATION_FAILED=1
              fi
          done
          
          echo ""
          if [ $VALIDATION_FAILED -eq 1 ]; then
              echo "VALIDATION FAILED: Missing required configuration parameters"
              echo "DEPLOYMENT BLOCKED: Fix configuration and try again"
              exit 1
          fi
          
          echo "All configuration parameters validated successfully"
          echo "=================================================="
          echo "Payment gateway is cleared for startup"
          exit 0
        volumeMounts:
        - name: config-volume
          mountPath: /config
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 50m
            memory: 64Mi
      containers:
      - name: gateway
        image: nginx:alpine
        ports:
        - containerPort: 8080
        env:
        - name: ENV
          value: production
        - name: LOG_LEVEL
          value: info
        volumeMounts:
        - name: config-volume
          mountPath: /etc/techflow
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: config-volume
        configMap:
          name: gateway-config
```

### Key Points in Solution
- Init container uses shell script to validate configuration file existence and content
- Volume is shared between init container and main container for configuration access
- Exit code 0 from init container allows main container to start; non-zero blocks startup
- Resource limits prevent resource exhaustion while allowing burst capacity
- Three replicas provide high availability for payment processing workload
- Clear logging in init container provides actionable error messages for troubleshooting

---

## Section 9: Test Cases

### Test Case 1: Namespace Existence Check
**Purpose:** Verify that the production namespace was created

**Test Logic:**
```bash
kubectl get namespace techflow-prod --no-headers
```

**Success Criteria:**
- Command exits with code 0
- Namespace exists in cluster

**Failure Message:**
```
Lab Failed: Namespace 'techflow-prod' does not exist
```

---

### Test Case 2: ConfigMap Existence Check
**Purpose:** Verify ConfigMap exists with correct name and namespace

**Test Logic:**
```bash
kubectl get configmap gateway-config -n techflow-prod --no-headers
```

**Success Criteria:**
- Command exits with code 0
- ConfigMap exists in techflow-prod namespace

**Failure Message:**
```
Lab Failed: ConfigMap 'gateway-config' does not exist in namespace 'techflow-prod'
```

---

### Test Case 3: ConfigMap Content Validation
**Purpose:** Verify ConfigMap contains all required configuration parameters

**Test Logic:**
```bash
CONFIG_DATA=$(kubectl get configmap gateway-config -n techflow-prod -o jsonpath='{.data.gateway\.conf}')

echo "$CONFIG_DATA" | grep -q "^SERVICE_NAME=" || exit 1
echo "$CONFIG_DATA" | grep -q "^SERVICE_VERSION=" || exit 1
echo "$CONFIG_DATA" | grep -q "^DATABASE_URL=" || exit 1
echo "$CONFIG_DATA" | grep -q "^REDIS_URL=" || exit 1
echo "$CONFIG_DATA" | grep -q "^MAX_CONNECTIONS=" || exit 1
echo "$CONFIG_DATA" | grep -q "^TIMEOUT_SECONDS=" || exit 1
```

**Success Criteria:**
- All 6 required keys are present in configuration
- Each key follows KEY=VALUE format

**Failure Message:**
```
Lab Failed: ConfigMap 'gateway-config' is missing one or more required parameters (SERVICE_NAME, SERVICE_VERSION, DATABASE_URL, REDIS_URL, MAX_CONNECTIONS, TIMEOUT_SECONDS)
```

---

### Test Case 4: Deployment Existence Check
**Purpose:** Verify deployment was created with correct name and namespace

**Test Logic:**
```bash
kubectl get deployment payment-gateway -n techflow-prod --no-headers
```

**Success Criteria:**
- Command exits with code 0
- Deployment exists in techflow-prod namespace

**Failure Message:**
```
Lab Failed: Deployment 'payment-gateway' does not exist in namespace 'techflow-prod'
```

---

### Test Case 5: Replica Count Check
**Purpose:** Verify deployment has exactly 3 replicas configured

**Test Logic:**
```bash
REPLICAS=$(kubectl get deployment payment-gateway -n techflow-prod -o jsonpath='{.spec.replicas}')

if [ "$REPLICAS" != "3" ]; then
    exit 1
fi
```

**Success Criteria:**
- Deployment spec specifies 3 replicas

**Failure Message:**
```
Lab Failed: Deployment 'payment-gateway' does not have 3 replicas configured (found: X replicas)
```

---

### Test Case 6: Init Container Presence Check
**Purpose:** Verify init container named 'config-guardian' exists in deployment

**Test Logic:**
```bash
INIT_CONTAINER=$(kubectl get deployment payment-gateway -n techflow-prod -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="config-guardian")].name}')

if [ "$INIT_CONTAINER" != "config-guardian" ]; then
    exit 1
fi
```

**Success Criteria:**
- Init container with name 'config-guardian' is present in pod template

**Failure Message:**
```
Lab Failed: Init container 'config-guardian' not found in deployment 'payment-gateway'
```

---

### Test Case 7: Init Container Volume Mount Check
**Purpose:** Verify init container mounts ConfigMap at correct path

**Test Logic:**
```bash
INIT_MOUNT=$(kubectl get deployment payment-gateway -n techflow-prod -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="config-guardian")].volumeMounts[*].mountPath}')

if ! echo "$INIT_MOUNT" | grep -q "/config"; then
    exit 1
fi
```

**Success Criteria:**
- Init container has volume mount at /config path

**Failure Message:**
```
Lab Failed: Init container 'config-guardian' does not mount volume at '/config'
```

---

### Test Case 8: Main Container Presence Check
**Purpose:** Verify main container named 'gateway' exists in deployment

**Test Logic:**
```bash
MAIN_CONTAINER=$(kubectl get deployment payment-gateway -n techflow-prod -o jsonpath='{.spec.template.spec.containers[?(@.name=="gateway")].name}')

if [ "$MAIN_CONTAINER" != "gateway" ]; then
    exit 1
fi
```

**Success Criteria:**
- Main container with name 'gateway' is present in pod template

**Failure Message:**
```
Lab Failed: Main container 'gateway' not found in deployment 'payment-gateway'
```

---

### Test Case 9: Main Container Volume Mount Check
**Purpose:** Verify main container mounts ConfigMap at correct path

**Test Logic:**
```bash
MAIN_MOUNT=$(kubectl get deployment payment-gateway -n techflow-prod -o jsonpath='{.spec.template.spec.containers[?(@.name=="gateway")].volumeMounts[*].mountPath}')

if ! echo "$MAIN_MOUNT" | grep -q "/etc/techflow"; then
    exit 1
fi
```

**Success Criteria:**
- Main container has volume mount at /etc/techflow path

**Failure Message:**
```
Lab Failed: Main container 'gateway' does not mount volume at '/etc/techflow'
```

---

### Test Case 10: Resource Limits Check - Init Container
**Purpose:** Verify init container has correct resource requests and limits

**Test Logic:**
```bash
INIT_CPU_REQUEST=$(kubectl get deployment payment-gateway -n techflow-prod -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="config-guardian")].resources.requests.cpu}')
INIT_CPU_LIMIT=$(kubectl get deployment payment-gateway -n techflow-prod -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="config-guardian")].resources.limits.cpu}')
INIT_MEM_REQUEST=$(kubectl get deployment payment-gateway -n techflow-prod -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="config-guardian")].resources.requests.memory}')
INIT_MEM_LIMIT=$(kubectl get deployment payment-gateway -n techflow-prod -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="config-guardian")].resources.limits.memory}')

if [ "$INIT_CPU_REQUEST" != "50m" ] || [ "$INIT_CPU_LIMIT" != "50m" ]; then
    exit 1
fi

if [ "$INIT_MEM_REQUEST" != "64Mi" ] || [ "$INIT_MEM_LIMIT" != "64Mi" ]; then
    exit 1
fi
```

**Success Criteria:**
- Init container CPU request: 50m
- Init container CPU limit: 50m
- Init container memory request: 64Mi
- Init container memory limit: 64Mi

**Failure Message:**
```
Lab Failed: Init container 'config-guardian' does not have correct resource limits (expected CPU: 50m/50m, Memory: 64Mi/64Mi)
```

---

### Test Case 11: Resource Limits Check - Main Container
**Purpose:** Verify main container has correct resource requests and limits

**Test Logic:**
```bash
MAIN_CPU_REQUEST=$(kubectl get deployment payment-gateway -n techflow-prod -o jsonpath='{.spec.template.spec.containers[?(@.name=="gateway")].resources.requests.cpu}')
MAIN_CPU_LIMIT=$(kubectl get deployment payment-gateway -n techflow-prod -o jsonpath='{.spec.template.spec.containers[?(@.name=="gateway")].resources.limits.cpu}')
MAIN_MEM_REQUEST=$(kubectl get deployment payment-gateway -n techflow-prod -o jsonpath='{.spec.template.spec.containers[?(@.name=="gateway")].resources.requests.memory}')
MAIN_MEM_LIMIT=$(kubectl get deployment payment-gateway -n techflow-prod -o jsonpath='{.spec.template.spec.containers[?(@.name=="gateway")].resources.limits.memory}')

if [ "$MAIN_CPU_REQUEST" != "200m" ] || [ "$MAIN_CPU_LIMIT" != "500m" ]; then
    exit 1
fi

if [ "$MAIN_MEM_REQUEST" != "256Mi" ] || [ "$MAIN_MEM_LIMIT" != "512Mi" ]; then
    exit 1
fi
```

**Success Criteria:**
- Main container CPU request: 200m
- Main container CPU limit: 500m
- Main container memory request: 256Mi
- Main container memory limit: 512Mi

**Failure Message:**
```
Lab Failed: Main container 'gateway' does not have correct resource limits (expected CPU: 200m/500m, Memory: 256Mi/512Mi)
```

---

### Test Case 12: Pod Running Status Check
**Purpose:** Verify all pods reach Running state

**Test Logic:**
```bash
# Wait up to 60 seconds for pods to be ready
for i in {1..60}; do
    READY_PODS=$(kubectl get pods -n techflow-prod -l app=payment-gateway --field-selector=status.phase=Running --no-headers | wc -l)
    if [ "$READY_PODS" -eq 3 ]; then
        break
    fi
    sleep 1
done

if [ "$READY_PODS" -ne 3 ]; then
    exit 1
fi
```

**Success Criteria:**
- All 3 pods reach Running state
- Pods have 1/1 containers ready

**Failure Message:**
```
Lab Failed: Not all pods are running. Expected 3 running pods, found X
```

---

### Test Case 13: Init Container Validation Success Check
**Purpose:** Verify init container successfully validates configuration

**Test Logic:**
```bash
POD_NAME=$(kubectl get pods -n techflow-prod -l app=payment-gateway --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

INIT_LOGS=$(kubectl logs $POD_NAME -n techflow-prod -c config-guardian)

if ! echo "$INIT_LOGS" | grep -q "All configuration parameters validated successfully"; then
    exit 1
fi

if ! echo "$INIT_LOGS" | grep -q "Payment gateway is cleared for startup"; then
    exit 1
fi
```

**Success Criteria:**
- Init container logs show successful validation message
- Init container completed with exit code 0

**Failure Message:**
```
Lab Failed: Init container did not successfully validate configuration. Check logs for validation errors
```

---

### Test Case 14: Configuration File Accessibility Check
**Purpose:** Verify configuration file is accessible in main container

**Test Logic:**
```bash
POD_NAME=$(kubectl get pods -n techflow-prod -l app=payment-gateway --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

kubectl exec $POD_NAME -n techflow-prod -c gateway -- test -f /etc/techflow/gateway.conf

if [ $? -ne 0 ]; then
    exit 1
fi
```

**Success Criteria:**
- Configuration file exists at /etc/techflow/gateway.conf in main container
- File is readable

**Failure Message:**
```
Lab Failed: Configuration file not accessible in main container at '/etc/techflow/gateway.conf'
```

---

### Test Case 15: Failure Safety Test - Missing ConfigMap
**Purpose:** Verify pods fail to start when ConfigMap is missing

**Test Logic:**
```bash
# Save current ConfigMap
kubectl get configmap gateway-config -n techflow-prod -o yaml > /tmp/gateway-config-backup.yaml

# Delete ConfigMap
kubectl delete configmap gateway-config -n techflow-prod

# Try to scale up
kubectl scale deployment payment-gateway -n techflow-prod --replicas=4

# Wait for new pod to be created
sleep 10

# Check if new pod is NOT running (should be in Init state)
NEW_POD_STATUS=$(kubectl get pods -n techflow-prod -l app=payment-gateway --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].status.phase}')

# Restore ConfigMap
kubectl apply -f /tmp/gateway-config-backup.yaml

# Scale back to 3
kubectl scale deployment payment-gateway -n techflow-prod --replicas=3

if [ "$NEW_POD_STATUS" == "Running" ]; then
    exit 1
fi
```

**Success Criteria:**
- New pod does not reach Running state when ConfigMap is missing
- Pod is stuck in Init phase

**Failure Message:**
```
Lab Failed: Pod started successfully even when ConfigMap was missing. Init container should prevent this
```

---

### Test Case 16: Failure Safety Test - Incomplete ConfigMap
**Purpose:** Verify pods fail to start when ConfigMap is missing required keys

**Test Logic:**
```bash
# Save current ConfigMap
kubectl get configmap gateway-config -n techflow-prod -o yaml > /tmp/gateway-config-backup.yaml

# Create incomplete ConfigMap (missing DATABASE_URL)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gateway-config
  namespace: techflow-prod
data:
  gateway.conf: |
    SERVICE_NAME=payment-gateway
    SERVICE_VERSION=3.2.1
    REDIS_URL=redis://cache.techflow-prod.svc.cluster.local:6379
    MAX_CONNECTIONS=100
    TIMEOUT_SECONDS=30
EOF

# Trigger rollout
kubectl rollout restart deployment payment-gateway -n techflow-prod

# Wait for rollout to create new pods
sleep 15

# Check if any pods are stuck in Init state
INIT_PODS=$(kubectl get pods -n techflow-prod -l app=payment-gateway | grep -c "Init:" || true)

# Restore ConfigMap
kubectl apply -f /tmp/gateway-config-backup.yaml

# Wait for rollout to complete
kubectl rollout status deployment payment-gateway -n techflow-prod --timeout=60s

if [ "$INIT_PODS" -eq 0 ]; then
    exit 1
fi
```

**Success Criteria:**
- New pods fail to start when ConfigMap is incomplete
- Pods are stuck in Init phase
- Init container logs show validation failure

**Failure Message:**
```
Lab Failed: Pods started successfully even with incomplete ConfigMap. Init container should validate all required keys
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
NAMESPACE="techflow-prod"
CONFIGMAP_NAME="gateway-config"
DEPLOYMENT_NAME="payment-gateway"
INIT_CONTAINER_NAME="config-guardian"
MAIN_CONTAINER_NAME="gateway"
REQUIRED_REPLICAS=3

# Test Case 1: Namespace Existence Check
function test_namespace_exists() {
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    print_status "success" "Lab Passed: Namespace '$NAMESPACE' exists"
}

# Test Case 2: ConfigMap Existence Check
function test_configmap_exists() {
    if ! kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: ConfigMap '$CONFIGMAP_NAME' does not exist in namespace '$NAMESPACE'"
        exit 1
    fi
    print_status "success" "Lab Passed: ConfigMap '$CONFIGMAP_NAME' exists"
}

# Test Case 3: ConfigMap Content Validation
function test_configmap_content() {
    CONFIG_DATA=$(kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.gateway\.conf}')
    
    REQUIRED_KEYS=("SERVICE_NAME" "SERVICE_VERSION" "DATABASE_URL" "REDIS_URL" "MAX_CONNECTIONS" "TIMEOUT_SECONDS")
    
    for key in "${REQUIRED_KEYS[@]}"; do
        if ! echo "$CONFIG_DATA" | grep -q "^${key}="; then
            print_status "failed" "Lab Failed: ConfigMap is missing required parameter: $key"
            exit 1
        fi
    done
    
    print_status "success" "Lab Passed: ConfigMap contains all required parameters"
}

# Test Case 4: Deployment Existence Check
function test_deployment_exists() {
    if ! kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: Deployment '$DEPLOYMENT_NAME' does not exist in namespace '$NAMESPACE'"
        exit 1
    fi
    print_status "success" "Lab Passed: Deployment '$DEPLOYMENT_NAME' exists"
}

# Test Case 5: Replica Count Check
function test_replica_count() {
    REPLICAS=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
    
    if [ "$REPLICAS" != "$REQUIRED_REPLICAS" ]; then
        print_status "failed" "Lab Failed: Deployment does not have $REQUIRED_REPLICAS replicas (found: $REPLICAS)"
        exit 1
    fi
    print_status "success" "Lab Passed: Deployment has correct replica count"
}

# Test Case 6: Init Container Presence Check
function test_init_container_exists() {
    INIT_CONTAINER=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="'"$INIT_CONTAINER_NAME"'")].name}')
    
    if [ "$INIT_CONTAINER" != "$INIT_CONTAINER_NAME" ]; then
        print_status "failed" "Lab Failed: Init container '$INIT_CONTAINER_NAME' not found"
        exit 1
    fi
    print_status "success" "Lab Passed: Init container exists"
}

# Test Case 7: Init Container Volume Mount Check
function test_init_volume_mount() {
    INIT_MOUNT=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="'"$INIT_CONTAINER_NAME"'")].volumeMounts[*].mountPath}')
    
    if ! echo "$INIT_MOUNT" | grep -q "/config"; then
        print_status "failed" "Lab Failed: Init container does not mount volume at '/config'"
        exit 1
    fi
    print_status "success" "Lab Passed: Init container has correct volume mount"
}

# Test Case 8: Main Container Presence Check
function test_main_container_exists() {
    MAIN_CONTAINER=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER_NAME"'")].name}')
    
    if [ "$MAIN_CONTAINER" != "$MAIN_CONTAINER_NAME" ]; then
        print_status "failed" "Lab Failed: Main container '$MAIN_CONTAINER_NAME' not found"
        exit 1
    fi
    print_status "success" "Lab Passed: Main container exists"
}

# Test Case 9: Main Container Volume Mount Check
function test_main_volume_mount() {
    MAIN_MOUNT=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER_NAME"'")].volumeMounts[*].mountPath}')
    
    if ! echo "$MAIN_MOUNT" | grep -q "/etc/techflow"; then
        print_status "failed" "Lab Failed: Main container does not mount volume at '/etc/techflow'"
        exit 1
    fi
    print_status "success" "Lab Passed: Main container has correct volume mount"
}

# Test Case 10: Resource Limits Check - Init Container
function test_init_resources() {
    INIT_CPU_REQUEST=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="'"$INIT_CONTAINER_NAME"'")].resources.requests.cpu}')
    INIT_CPU_LIMIT=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="'"$INIT_CONTAINER_NAME"'")].resources.limits.cpu}')
    INIT_MEM_REQUEST=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="'"$INIT_CONTAINER_NAME"'")].resources.requests.memory}')
    INIT_MEM_LIMIT=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="'"$INIT_CONTAINER_NAME"'")].resources.limits.memory}')
    
    if [ "$INIT_CPU_REQUEST" != "50m" ] || [ "$INIT_CPU_LIMIT" != "50m" ] || [ "$INIT_MEM_REQUEST" != "64Mi" ] || [ "$INIT_MEM_LIMIT" != "64Mi" ]; then
        print_status "failed" "Lab Failed: Init container does not have correct resource limits"
        exit 1
    fi
    print_status "success" "Lab Passed: Init container has correct resource limits"
}

# Test Case 11: Resource Limits Check - Main Container
function test_main_resources() {
    MAIN_CPU_REQUEST=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER_NAME"'")].resources.requests.cpu}')
    MAIN_CPU_LIMIT=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER_NAME"'")].resources.limits.cpu}')
    MAIN_MEM_REQUEST=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER_NAME"'")].resources.requests.memory}')
    MAIN_MEM_LIMIT=$(kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER_NAME"'")].resources.limits.memory}')
    
    if [ "$MAIN_CPU_REQUEST" != "200m" ] || [ "$MAIN_CPU_LIMIT" != "500m" ] || [ "$MAIN_MEM_REQUEST" != "256Mi" ] || [ "$MAIN_MEM_LIMIT" != "512Mi" ]; then
        print_status "failed" "Lab Failed: Main container does not have correct resource limits"
        exit 1
    fi
    print_status "success" "Lab Passed: Main container has correct resource limits"
}

# Test Case 12: Pod Running Status Check
function test_pods_running() {
    for i in {1..60}; do
        READY_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=payment-gateway --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        if [ "$READY_PODS" -eq "$REQUIRED_REPLICAS" ]; then
            print_status "success" "Lab Passed: All pods are running"
            return 0
        fi
        sleep 1
    done
    
    READY_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=payment-gateway --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    print_status "failed" "Lab Failed: Not all pods are running (expected: $REQUIRED_REPLICAS, found: $READY_PODS)"
    exit 1
}

# Test Case 13: Init Container Validation Success Check
function test_init_validation() {
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=payment-gateway --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$POD_NAME" ]; then
        print_status "failed" "Lab Failed: No running pods found to check init container logs"
        exit 1
    fi
    
    INIT_LOGS=$(kubectl logs "$POD_NAME" -n "$NAMESPACE" -c "$INIT_CONTAINER_NAME" 2>/dev/null)
    
    if ! echo "$INIT_LOGS" | grep -q "All configuration parameters validated successfully"; then
        print_status "failed" "Lab Failed: Init container did not successfully validate configuration"
        exit 1
    fi
    
    print_status "success" "Lab Passed: Init container successfully validated configuration"
}

# Test Case 14: Configuration File Accessibility Check
function test_config_file_accessible() {
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=payment-gateway --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$POD_NAME" ]; then
        print_status "failed" "Lab Failed: No running pods found to check config file"
        exit 1
    fi
    
    if ! kubectl exec "$POD_NAME" -n "$NAMESPACE" -c "$MAIN_CONTAINER_NAME" -- test -f /etc/techflow/gateway.conf &>/dev/null; then
        print_status "failed" "Lab Failed: Configuration file not accessible in main container"
        exit 1
    fi
    
    print_status "success" "Lab Passed: Configuration file is accessible in main container"
}

# Execute all tests
test_namespace_exists
test_configmap_exists
test_configmap_content
test_deployment_exists
test_replica_count
test_init_container_exists
test_init_volume_mount
test_main_container_exists
test_main_volume_mount
test_init_resources
test_main_resources
test_pods_running
test_init_validation
test_config_file_accessible

exit 0
```

---

## Section 10: Setup Script

### Pre-Lab Environment Setup

**What needs to be configured before student starts:**
- Kubernetes cluster must be running and accessible
- kubectl must be configured with cluster access
- Student must have permissions to create namespaces, deployments, configmaps
- No pre-existing resources should conflict with lab resources

### Setup Script

```bash
#!/bin/bash

set -euo pipefail

# Variables
NAMESPACE="techflow-prod"
CONFIGMAP_NAME="gateway-config"
DEPLOYMENT_NAME="payment-gateway"

echo "Starting pre-lab cleanup..."

# Function: Clean up any existing lab resources
function cleanup_existing_resources() {
    echo "Checking for existing lab resources..."
    
    # Delete deployment if exists
    if kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &>/dev/null; then
        echo "Deleting existing deployment: $DEPLOYMENT_NAME"
        kubectl delete deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --ignore-not-found=true
    fi
    
    # Delete configmap if exists
    if kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" &>/dev/null; then
        echo "Deleting existing ConfigMap: $CONFIGMAP_NAME"
        kubectl delete configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" --ignore-not-found=true
    fi
    
    # Delete namespace if exists
    if kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo "Deleting existing namespace: $NAMESPACE"
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
        
        # Wait for namespace to be fully deleted
        echo "Waiting for namespace deletion to complete..."
        for i in {1..30}; do
            if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
                break
            fi
            sleep 2
        done
    fi
    
    echo "Cleanup completed successfully"
}

# Function: Verify cluster is accessible
function verify_cluster_access() {
    echo "Verifying Kubernetes cluster access..."
    
    if ! kubectl cluster-info &>/dev/null; then
        echo "ERROR: Cannot access Kubernetes cluster"
        exit 1
    fi
    
    echo "Cluster access verified"
}

# Function: Verify required permissions
function verify_permissions() {
    echo "Verifying required permissions..."
    
    # Test if we can create a namespace
    TEST_NS="permission-test-$$"
    if kubectl create namespace "$TEST_NS" &>/dev/null; then
        kubectl delete namespace "$TEST_NS" &>/dev/null
        echo "Permissions verified"
    else
        echo "ERROR: Insufficient permissions to create resources"
        exit 1
    fi
}

# Execute setup
verify_cluster_access
verify_permissions
cleanup_existing_resources

echo ""
echo "Lab environment setup completed successfully"
echo "Students can now begin the lab"
```

### Setup Verification

**After running setup script, verify:**
```bash
# Check 1: Verify cluster is accessible
kubectl cluster-info

# Check 2: Verify namespace does not exist
kubectl get namespace techflow-prod 2>&1 | grep -q "NotFound"

# Check 3: Verify no existing resources
kubectl get all -n techflow-prod 2>&1 | grep -q "No resources found"
```

---

**Template Version:** 1.0  
**Last Updated:** December 2024