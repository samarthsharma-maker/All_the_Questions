# Kubernetes Secure Deployment Challenge

## Scenario

You are a DevOps engineer responsible for completing the deployment of a microservice application. A basic deployment and service have been created, but they are missing critical components:

- Configuration management (ConfigMap and Secret)
- Health checks (Readiness Probe)
- Resource management (requests and limits)

Your task is to create the missing ConfigMap and Secret, then update the existing Deployment to include readiness probes and resource constraints.

---

## Problem Statement

A partial deployment named `microservice-app` exists in the `default` namespace along with a service `microservice-svc`. You need to:

1. **Create ConfigMap and Secret** with application configuration and credentials
2. **Update the Deployment** to mount ConfigMap, inject environment variables, add readiness probe, and set resource limits

---

## What's Already Provided

### Existing Deployment: `microservice-app`
- 3 replicas
- nginx:alpine image
- Labels: app=microservice
- Rolling update strategy (maxSurge: 1, maxUnavailable: 0)
- Liveness probe configured
- Missing: ConfigMap volume mount
- Missing: Environment variables from ConfigMap and Secret
- Missing: Readiness probe
- Missing: Resource requests and limits

### Existing Service: `microservice-svc`
- Type: ClusterIP
- Selector: app=microservice
- Port: 80 → TargetPort: 80

---

## Your Tasks

### Task 1: Create ConfigMap `app-config`

Create a ConfigMap named `app-config` in the `default` namespace containing:

**File-based Configuration:**
- A file named `app.properties` with the following content:
  ```
  server.port=8080
  app.environment=production
  log.level=info
  ```

**Key-Value Configuration:**
- `MAX_CONNECTIONS` with value `100`
- `CACHE_TTL` with value `3600`

---

### Task 2: Create Secret `app-secrets`

Create a Secret named `app-secrets` in the `default` namespace containing:

**Database Credentials:**
- `db-username`: `admin_user` (base64 encoded)
- `db-password`: `SecureP@ssw0rd123` (base64 encoded)

**API Credentials:**
- `api-key`: `1234567890abcdef` (base64 encoded)

**Note:** Values must be base64 encoded in the YAML manifest.

---

### Task 3: Update Deployment `microservice-app`

Update the existing deployment to add the following:

#### 3.1 Volume Mount for ConfigMap
- Mount the entire `app-config` ConfigMap as a volume at `/etc/config`
- The mounted files should be read-only

#### 3.2 Environment Variables from ConfigMap
- `MAX_CONNECTIONS` → from ConfigMap key `MAX_CONNECTIONS`
- `CACHE_TTL` → from ConfigMap key `CACHE_TTL`

#### 3.3 Environment Variables from Secret
- `DB_USERNAME` → from Secret key `db-username`
- `DB_PASSWORD` → from Secret key `db-password`
- `API_KEY` → from Secret key `api-key`

#### 3.4 Add Readiness Probe
- Type: HTTP GET
- Path: `/`
- Port: `80`
- Initial delay: `5` seconds
- Period: `10` seconds

#### 3.5 Add Resource Management
- **Requests:**
  - CPU: `100m`
  - Memory: `128Mi`
- **Limits:**
  - CPU: `200m`
  - Memory: `256Mi`

---

## Deliverables

Create the following files:

1. `configmap.yaml` - ConfigMap resource with app.properties and key-value pairs
2. `secret.yaml` - Secret resource with base64 encoded credentials
3. `deployment-patch.yaml` - Updated deployment with all required additions

**OR** use `kubectl edit` to directly modify the existing deployment after creating ConfigMap and Secret.

---


## Expected Behavior

After successful deployment:

- 3 pods running with the `microservice` label
- ConfigMap mounted at `/etc/config/app.properties`
- Environment variables correctly set from ConfigMap and Secret
- Service accessible within the cluster
- Rolling updates complete without downtime
- Health probes functioning (pods become Ready after 5 seconds)

---
