# Kubernetes RBAC – Access Control & Least Privilege


## Context

### Company Background

- **Company Name:** FinanceFlow Technologies  
- **Industry:** Financial Services & Payment Processing  
- **Scale:** Enterprise (800 employees)  
- **Core Business:**  
  Payment processing platform handling:
  - $5B in annual transactions  
  - 10,000 merchant clients  
  - 50M transactions per month  
  - $200M ARR  

---

### The Incident

**What happened:**  
On Tuesday afternoon, a junior developer accidentally deleted the production PostgreSQL StatefulSet while attempting to clean up resources in a development namespace.

The developer had been granted **cluster-admin** privileges “temporarily” for a migration project three months earlier. That access was never revoked.

The developer executed:
```bash
kubectl delete statefulset postgres-primary -n production
```

They believed they were operating in the development namespace.

**Immediate result:**

* Production database pods were terminated
* All payment processing stopped
* 15,000 active transactions were lost

**When it occurred:**

* Tuesday, 2:15 PM (peak transaction processing hours)

---

### Business Impact

* Complete service outage for **4 hours**
* **15,000 transactions lost** (worth $2.3M)
* **10,000 merchants** unable to process payments
* Estimated revenue loss: **$8M**
* SLA penalties: **$500K**
* **PCI-DSS compliance violation**
* **SOC 2 audit failure risk**
* Three major clients (30% of revenue) threatening to churn
* Federal regulators notified (CFPB investigation)
* Stock price dropped **12%**
* Emergency board meeting
* CISO resignation
* Legal action threatened
* Brand reputation damage
* Social media backlash (`#FinanceFlowFail`)
* 24/7 incident response for entire engineering team
* Database restore took **4 hours** (backups were 2 hours old)

---

### Symptoms Observed

* Developer had `cluster-admin` ClusterRoleBinding
* No namespace restrictions
* ServiceAccounts with excessive permissions
* No audit trail for permission grants
* `kubectl auth can-i --list` showed full cluster access
* No MFA or approval for destructive operations
* No separation between dev and prod access
* All developers shared identical permissions
* No protection for critical resources
* No PodDisruptionBudgets

---

### Root Cause Analysis

**Primary Cause:**
A developer retained **cluster-admin** privileges long after a temporary task ended. This allowed unrestricted actions across all namespaces, including production.

**Contributing Factors:**

* “Just give them cluster-admin” culture
* No process for temporary privilege escalation or revocation
* No separation between development and production
* Over-privileged ServiceAccounts
* Missing audit logging for RBAC changes
* No namespace-scoped access controls
* Poor kubectl context awareness
* No safeguards for critical resources
* No approval workflow for destructive actions
* No regular RBAC reviews
* Reliance on human caution instead of technical controls
* No RBAC training
* No RBAC testing
* Infrastructure team under pressure and cutting corners

---

### Why This Matters

RBAC is the **primary security control** in Kubernetes.
Granting `cluster-admin` violates the **principle of least privilege** and creates catastrophic risk.

In regulated industries (finance, healthcare):

* Excessive privileges violate **PCI-DSS, SOC 2, HIPAA**
* Lead to fines, audit failures, legal exposure
* A single mistaken command can destroy production

---

### Your Mission

**Your Role:**
Principal Security Engineer / Cloud Security Architect

**Assigned By:**
CEO, CTO, Acting CISO, Chief Compliance Officer, General Counsel

**Mandate:**
The board requires a **complete RBAC overhaul within 48 hours**.
Federal regulators demand documented proof of proper access controls.

You have:

* Full authority
* Unlimited resources
* All engineering work paused until RBAC is fixed

---

### Objectives

You must:

* Remove all developer `cluster-admin` access
* Implement namespace-scoped RBAC
* Define clear personas:

  * Developer
  * Viewer
  * CI/CD Deployer
* Separate development and production access
* Minimize ServiceAccount permissions
* Produce auditable documentation for compliance

---

### Success Criteria

* No developers have `cluster-admin`
* Namespace-scoped Roles exist:

  * `developer-role` (development)
  * `prod-viewer` (production)
* CI/CD ServiceAccount has deploy-only permissions
* Developers can access **dev only**
* Production is **read-only** for most users
* Critical resources are protected
* All RBAC changes are auditable
* Compliance officer approves the model
* Incident is no longer possible

---

## Task Description

### Lab Environment Setup

#### Provided Resources

* Kubernetes cluster with RBAC enabled
* Namespaces:

  * `production`
  * `staging`
  * `development`
* `kubectl` access with cluster-admin (setup only)
* Multiple users and ServiceAccounts

---

### Current State (Insecure)

* All developers have `cluster-admin`
* ServiceAccounts are over-privileged
* No namespace separation

### Target State (Secure)

* Least-privilege RBAC
* Namespace isolation
* Controlled production access

---

## Tasks Breakdown

---

### Task 1: Audit Current RBAC Configuration

**Objective:**
Understand the existing security failures.

**Steps:**

* List all `ClusterRoleBindings`
* Identify users and ServiceAccounts bound to `cluster-admin`
* Inspect namespace-level `RoleBindings`
* Document excessive permissions
* Identify security gaps

**Expected Outcome:**
A documented assessment of RBAC violations.

---

### Task 2: Create Developer Role (Namespace-Scoped)

**Objective:**
Allow developers to work only in the development namespace.

**Steps:**

* Create a Role named `developer-role` in `development`
* Grant permissions:

  * Verbs: `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`
  * Resources:

    * pods
    * services
    * deployments
    * configmaps
    * secrets
* Bind the Role to developer users or ServiceAccounts
* Test access in the development namespace

**Expected Outcome:**
Developers can fully manage dev resources only.

---

### Task 3: Create Production Viewer Role

**Objective:**
Provide read-only access to production.

**Steps:**

* Create Role `prod-viewer` in `production`
* Grant permissions:

  * Verbs: `get`, `list`, `watch`
* Resources:

  * pods
  * services
  * deployments
  * logs
* Bind Role to developer group
* Verify no write access exists

**Expected Outcome:**
Developers can view production but cannot modify it.

---

### Task 4: Create CI/CD ServiceAccount with Deployer Role

**Objective:**
Limit automation to safe deployment actions.

**Steps:**

* Create ServiceAccount `cicd-deployer`
* Create a Role with permissions:

  * Verbs: `get`, `create`, `update`, `patch`
  * Resource: `deployments`
* Explicitly exclude delete permissions
* Bind ServiceAccount to Role

**Expected Outcome:**
CI/CD can deploy updates but cannot delete workloads.

---

### Task 5: Remove Cluster-Admin Bindings

**Objective:**
Revoke excessive privileges.

**Steps:**

* List all `ClusterRoleBindings` to `cluster-admin`
* Remove bindings for developers and non-admin users
* Retain access only for designated cluster administrators
* Verify developers no longer have cluster-wide access
* Confirm namespace-scoped access still works

**Expected Outcome:**
`cluster-admin` is restricted to true administrators only.

---

### Task 6: Test and Verify RBAC

**Objective:**
Ensure least privilege is enforced.

**Steps:**

* Verify developer can create a pod in `development`
* Verify developer **cannot** delete resources in `production`
* Verify developer **cannot** view production secrets
* Verify CI/CD ServiceAccount can deploy
* Verify CI/CD ServiceAccount **cannot** delete deployments
* Document test results

**Expected Outcome:**
RBAC behaves exactly as designed.

---

## Verification Checklist

You must confirm:

* No developers are bound to `cluster-admin`
* `developer-role` exists in `development` with correct permissions
* `prod-viewer` exists in `production` with read-only permissions
* `cicd-deployer` ServiceAccount has limited deploy permissions
* Developers can create resources in development
* Developers cannot modify or delete production resources
* CI/CD can deploy but cannot delete workloads

---

**End of Lab Assignment**


