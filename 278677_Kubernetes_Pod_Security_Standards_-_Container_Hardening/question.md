## Kubernetes Pod Security Standards – Container Hardening


## Context

### Company Background

- **Company Name:** MediSecure Healthcare  
- **Industry:** Healthcare Technology & Medical Records  
- **Scale:** Large healthcare provider (1,200 employees)  
- **Core Business:**  
  Electronic Health Records (EHR) platform serving:
  - 500 hospitals  
  - 50 million patient records  
  - 10 million daily transactions  
  - $300M ARR  

---

### The Incident

**What happened:**  
During a routine SOC 2 + HIPAA compliance audit, the security team discovered that the `patient-data-processor` deployment was running containers as **root** with **privileged mode enabled**. Containers were allowed to escalate privileges, had unrestricted Linux capabilities, and were mounting host filesystem paths.

A penetration tester demonstrated a **container escape** in under 15 minutes, gaining access to the underlying node and potentially all patient data on that server.

The audit revealed that **15 out of 20 production deployments** had similar misconfigurations.

**When it occurred:**  
- Monday morning during scheduled compliance audit

---

### Business Impact

- Critical **HIPAA compliance violation**
- Containers running as root with privileged access
- High risk of host and cluster compromise
- **50 million patient records** potentially exposed
- Immediate audit failure; HIPAA certification suspended
- Federal investigation by HHS Office for Civil Rights
- Potential fines:
  - $1.5M per violation
  - Up to $22.5M total
- Hospital clients notified of security risk
- Reputational damage across healthcare partners
- Three major hospital systems (40% of revenue) threatening termination
- Stock price dropped **18%**
- Class-action lawsuit filed by patients
- Emergency board meeting with CEO and CISO
- **30-day remediation deadline**
- Risk of halted business operations
- Cyber insurance coverage threatened
- Competitors using incident in sales pitches
- 24/7 incident response activated
- External security consultants hired ($500K)

---

### Symptoms Observed

- Containers running as UID `0` (root)
- `privileged: true` set in `securityContext`
- `allowPrivilegeEscalation: true` (default)
- No Linux capability restrictions
- HostPath volumes mounted (e.g., `/var/run/docker.sock`)
- No `readOnlyRootFilesystem`
- `runAsNonRoot` missing or set to `false`
- No `seccomp` or `AppArmor` profiles
- Containers able to modify host filesystem
- `kubectl describe pod` showed empty `securityContext`
- Container escape confirmed during penetration testing

---

### Root Cause Analysis

**Primary Cause:**  
Developers copied container configurations from online tutorials without understanding the security implications. When encountering permission issues, they enabled privileged mode and ran containers as root to “make things work”.

**Contributing Factors:**

- No Pod Security Standards enforcement
- Missing admission control policies
- Limited container security knowledge
- Culture of adding `privileged: true` to fix errors
- No security review of manifests
- Lack of security training
- No CI/CD security scanning
- Kubernetes defaults allow insecure configurations
- Poor understanding of Linux capabilities
- Root user used by default in base images
- No cluster-level policy enforcement
- Security team not involved in reviews
- Lack of testing for container security
- “Works on my machine” mindset
- Delivery pressure over security

---

### Why This Matters

Running containers as root with privileged mode is one of the most severe Kubernetes security risks.

A compromised container can:
- Escape to the host
- Access other workloads’ data
- Read secrets
- Modify the kernel
- Compromise the entire cluster

For healthcare organizations handling PHI:
- This violates HIPAA Security Rule requirements
- Leads to fines, certification loss, legal liability
- Puts patient safety and business survival at risk

Pod Security Standards exist specifically to prevent these failures.

---

### Your Mission

**Your Role:**  
Lead Security Engineer / Cloud Security Architect

**Assigned By:**  
CEO, CISO, Chief Compliance Officer, General Counsel, and federal auditors

**Mandate:**  
You have absolute authority and **30 days** to remediate all pod security issues cluster-wide. HIPAA certification and company survival depend on success.

---

### Objectives

You must:

- Implement Pod Security Standards cluster-wide
- Enforce the **Restricted** security profile
- Ensure containers:
  - Run as non-root
  - Are not privileged
  - Cannot escalate privileges
  - Drop all Linux capabilities
  - Use read-only root filesystems
- Enable Pod Security Admission at namespace level
- Produce documentation for HIPAA auditors

---

### Success Criteria

- All containers run as non-root (UID > 0)
- No privileged containers exist
- `allowPrivilegeEscalation: false` enforced
- All capabilities dropped (minimal added only if required)
- `readOnlyRootFilesystem: true` where feasible
- `runAsNonRoot: true` enforced
- Pod Security Admission enabled
- `Restricted` profile enforced in production
- Container escape is no longer possible
- HIPAA auditor approval received
- Compliance documentation completed

---

## Task Description

### Lab Environment Setup

#### Provided Resources

- Kubernetes cluster with Pod Security Admission enabled
- Namespaces:
  - `medisecure-prod`
  - `medisecure-dev`
- Pre-deployed insecure application
- `kubectl` CLI access

---

### Current State (Insecure)

- Containers running as root
- Privileged mode enabled
- No security controls
- Multiple HIPAA violations

### Target State (Secure)

- Hardened containers
- Restricted Pod Security profile enforced
- Least-privilege execution

---

## Tasks Breakdown

---

### Task 1: Audit Current Security Posture

**Objective:**  
Identify all security violations.

**Steps:**

- Check which UID containers are running as
- Verify if privileged mode is enabled
- Check `allowPrivilegeEscalation`
- Review Linux capabilities
- Check filesystem access settings
- Document all findings

**Expected Outcome:**  
Comprehensive list of container security violations.

---

### Task 2: Configure Pod Security Admission Labels

**Objective:**  
Enforce Pod Security Standards at namespace level.

**Steps:**

- Label namespace with:
  - `pod-security.kubernetes.io/enforce=restricted`
- Add `warn` and `audit` labels
- Understand:
  - Privileged
  - Baseline
  - Restricted profiles
- Test rejection of non-compliant pods

**Expected Outcome:**  
Restricted profile enforced in production namespace.

---

### Task 3: Configure `runAsNonRoot`

**Objective:**  
Prevent root execution.

**Steps:**

- Set `runAsNonRoot: true`
- Set `runAsUser` to a non-zero UID (e.g., 1000)
- Update image or Dockerfile if required
- Verify container starts successfully
- Confirm UID is not 0

**Expected Outcome:**  
Containers run as non-root users.

---

### Task 4: Disable Privileged Mode

**Objective:**  
Remove host-level access.

**Steps:**

- Set `privileged: false`
- Remove privileged configuration if present
- Verify application still works
- Confirm host resources are inaccessible

**Expected Outcome:**  
No privileged containers.

---

### Task 5: Disable Privilege Escalation

**Objective:**  
Prevent gaining additional privileges.

**Steps:**

- Set `allowPrivilegeEscalation: false`
- Apply to container `securityContext`
- Test privilege escalation attempts
- Verify `setuid` binaries are ineffective

**Expected Outcome:**  
Privilege escalation blocked.

---

### Task 6: Drop Capabilities and Set Seccomp

**Objective:**  
Apply least-privilege execution.

**Steps:**

- Drop all capabilities: `drop: ["ALL"]`
- Add back only strictly required capabilities
- Set `seccompProfile: RuntimeDefault`
- Test application functionality

**Expected Outcome:**  
Minimal capabilities with seccomp enforcement.

---

### Task 7: Enable Read-Only Root Filesystem

**Objective:**  
Prevent filesystem tampering.

**Steps:**

- Set `readOnlyRootFilesystem: true`
- Use `emptyDir` for writable paths
- Mount volumes for `/tmp`, `/var/run` if required
- Test application behavior

**Expected Outcome:**  
Root filesystem is immutable.

---

### Task 8: Verify and Test

**Objective:**  
Confirm Restricted profile compliance.

**Steps:**

- Apply hardened deployment
- Ensure pod starts successfully
- Validate application functionality
- Inspect security context
- Attempt privilege escalation (must fail)
- Document compliance evidence

**Expected Outcome:**  
Deployment fully complies with Restricted Pod Security Standards.

---

## Verification Checklist

You must verify:

- Namespace has Pod Security labels (`enforce=restricted`)
- Deployment has `runAsNonRoot: true`
- Deployment has `runAsUser > 0`
- Deployment has `privileged: false` or unset
- Deployment has `allowPrivilegeEscalation: false`
- Deployment drops all capabilities (`["ALL"]`)
- Deployment sets `seccompProfile: RuntimeDefault`
- Deployment sets `readOnlyRootFilesystem: true`
- Pods run successfully as non-root
- Application functions correctly

---

**End of Lab Assignment**
