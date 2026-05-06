# Kubernetes RBAC: Fixing a Broken CI Pipeline

## Context

### Company Background

**Company Name:** StackFlow Technologies
**Industry:** Developer Tooling / DevOps SaaS
**Scale:** Mid-size company (180 employees)

**Core Business:**
StackFlow Technologies provides a cloud-native CI/CD pipeline management platform serving:
- 300+ engineering teams across enterprise clients
- Processing over 50,000 pipeline runs per day
- Annual Recurring Revenue (ARR): $6M

---

### The Incident

**What happened:**
Four days ago, a junior engineer configured RBAC and Resource Quotas across the `dev` and `staging` namespaces to allow the automated CI pipeline to observe running pods during deployment verification. The configuration was pushed directly to the cluster without peer review.

Since the change, the pipeline is experiencing cascading failures at multiple stages:
1. **RBAC issues**: The pipeline service account cannot read pod status or stream container logs (403 Forbidden)
2. **Resource constraints**: New pod deployments are failing with ResourceQuota exhaustion errors

Engineering teams are deploying without any automated verification. The CI system appears to be sabotaged at multiple infrastructure layers.

**When it occurred:**
Reported Tuesday morning. The misconfiguration has been in place since Saturday's push.

**Impact on the business:**
- All 14 active engineering teams across dev and staging are deploying without automated verification
- On-call engineers are manually running kubectl commands after every deployment to compensate
- Two client-facing releases have been delayed pending manual confirmation
- The platform's core value proposition of automated deployment confidence is broken
- Resource quotas are also preventing legitimate deployment attempts in staging
- Engineering leadership has escalated this to the VP of Platform with P1 severity

---

### What You Know

The CI pipeline runs under a ServiceAccount shared across both `dev` and `staging` namespaces. During deployment verification, it needs to:
- Read and list running pods using the `pods` resource
- Stream container logs using the `pods/log` sub-resource to report build output
- Verify that new pods can be created within resource limits

The pipeline runner is reporting multiple errors:
- `403 Forbidden` on pod read operations and log access
- `Insufficient quota` when deploying new pods

You have full `kubectl` access to the cluster. The RBAC and Resource Quotas appear to have issues. You will need to inspect resources across both namespaces, reason about what is broken at each layer, and apply the necessary fixes.

---

### Your Mission

**Your Role:** Senior Platform Engineer

**Assigned By:** VP of Platform Engineering

**Objective:**
Investigate the infrastructure across both `dev` and `staging` namespaces, identify all misconfigurations in RBAC, Network Policies, and Resource Quotas, and fix them so the CI pipeline ServiceAccount can successfully verify deployments in both namespaces without any destructive permissions.

---

### Success Criteria

- The CI pipeline ServiceAccount exists in the correct namespace and is configured identically
- The ServiceAccount can read pod status and stream pod logs in **both** `dev` and `staging` namespaces
- The ServiceAccount cannot perform destructive operations such as delete, create, or update on any resource
- Network connectivity is restored for pod log streaming
- Resource quotas allow the pipeline to verify pod creation without exhausting limits
- All RBAC resources are correctly linked to each other
- Permissions are verified using `kubectl auth can-i` across both namespaces

---

## Environment Details

- **Namespaces:** `dev` and `staging`
- **Cluster:** K3s, pre-configured
- **Access:** Full `kubectl` access with cluster-admin permissions
- **Broken resources are already deployed** in both namespaces:
  - Misconfigured RBAC (ServiceAccounts, Roles, RoleBindings)
  - Blocking Network Policies
  - Broken Resource Quotas

---

## Tasks

### Task 1: Investigate All Misconfigurations

Inspect resources across both `dev` and `staging` namespaces:

**RBAC Layer:**
- Are ServiceAccounts deployed in the correct namespace?
- Are the permissions configured correctly in both Roles, including access to both `pods` and `pods/log`?
- Are the resources correctly linked via RoleBindings?

**Resource Management Layer:**
- Are Resource Quotas misconfigured or too restrictive?
- Can the CI pipeline verify pod creation without hitting quota limits?

Identify all issues before making changes. Document what's broken at each layer.

### Task 2: Fix All Misconfigurations

Apply corrections across both namespaces:

**RBAC Fixes:**
- Ensure CI pipeline ServiceAccount exists in both `dev` and `staging`
- Create/fix Roles with correct verbs (`get`, `list`, `watch`) on both `pods` and `pods/log` resources
- Ensure RoleBindings correctly bind ServiceAccounts to Roles in each namespace

**Resource Quota Fixes:**
- Set appropriate limits to allow CI pipeline deployment verification
- Ensure pods can be created without quota exhaustion
- **Recommended limits for CI pipeline operations:**
  - `pods`: At least 10-20 pods
  - `requests.memory`: At least 512Mi to 1Gi
  - `requests.cpu`: At least 0.5 to 2 cores

### Task 3: Verify Across Both Namespaces

Use `kubectl auth can-i` to confirm permissions in both namespaces:
- Verify `get`, `list`, `watch` permissions on `pods` in `dev` and `staging`
- Verify `get` permissions on `pods/log` (the sub-resource for log access) in both namespaces
- Confirm no destructive operations are permitted
- Verify ResourceQuotas allow pod creation

---

## Notes

- Do not delete and recreate the namespaces
- Apply all fixes using `kubectl apply`
- The `pods/log` sub-resource is required for streaming logs—check both verbs and resources
- Use `kubectl auth can-i --as=system:serviceaccount:dev:ci-runner -n dev` and same for `staging`
- Use `kubectl auth can-i get pods/log --as=system:serviceaccount:dev:ci-runner -n dev` to verify log access specifically
- Resource Quotas may prevent verification—inspect and adjust them