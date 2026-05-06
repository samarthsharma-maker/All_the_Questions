# Docker Security Hardening – Container Isolation & Least Privilege

---

## Context

### Company Background

- **Company Name:** SecureBank Financial Services  
- **Industry:** Banking & Financial Technology  
- **Scale:** Global bank (5,000 employees)  
- **Core Business:**  
  Online banking platform serving:
  - 10 million customers  
  - $50B in annual transactions  
  - $200B in managed assets  
  - $2B ARR  

---

### The Incident

**What happened:**  
During a mandatory PCI-DSS Level 1 compliance audit, external security consultants ran a container security scan using **Trivy** and discovered that all production Docker containers were running as **root (UID 0)** with default Docker capabilities. Containers were also running in **privileged mode**, had **no CPU or memory limits**, and stored **sensitive credentials directly in Dockerfiles**.

A penetration test demonstrated that an attacker could exploit a web application vulnerability to **escape the container and gain root access to the host**, potentially compromising the entire banking infrastructure.

**When it occurred:**  
- Tuesday morning during scheduled PCI-DSS Level 1 audit

---

### Business Impact

- Critical **PCI-DSS compliance failure**
- Immediate suspension risk for credit card processing
- $500M monthly revenue at risk
- Federal regulators (OCC, FDIC) notified
- Potential fines: $50K–$500K per month
- Visa/Mastercard threatening merchant revocation
- 10 million customers at risk
- Emergency board meeting
- CEO and CTO facing termination risk
- Stock price dropped **14%**
- Major clients moved $200M in deposits to competitors
- Cyber insurance coverage threatened
- **60-day remediation deadline**
- $2M external security consultants engaged
- All development halted
- 24/7 security incident response activated

---

### Symptoms Observed

- Containers running as root (UID 0)
- No `USER` directive in Dockerfiles
- Containers started with `--privileged`
- Default capabilities enabled (e.g., `CAP_SYS_ADMIN`)
- No CPU or memory limits
- Secrets hardcoded using `ENV` in Dockerfiles
- Writable root filesystem
- Trivy findings: `HIGH – Container running as root`
- Successful container escape during pentest
- `docker inspect` shows `"Privileged": true`
- No seccomp or AppArmor profiles
- Containers accessing host filesystem
- `docker top` shows all processes running as root

---

### Root Cause Analysis

**Primary Cause:**  
Developers followed outdated tutorials that ran containers as root. When permission errors occurred, they added `--privileged` or continued running as root to “make it work,” without understanding security implications.

**Contributing Factors:**

- No Docker security training
- Copy-pasted Dockerfiles from unverified sources
- No security review process
- No automated security scanning (Trivy, Snyk, Clair)
- Default Docker behavior allows root execution
- Poor understanding of Linux capabilities
- Overuse of `--privileged`
- No enforcement of least privilege
- Security team excluded from container reviews
- No resource limits (DoS risk)
- Secrets committed into image layers
- No separation of dev and prod images
- Pressure to ship quickly over security

---

### Why This Matters

Running Docker containers as root with default capabilities is a severe security risk. A compromised container can:

- Escape to the host
- Access sensitive banking data
- Modify system configuration
- Compromise entire servers

For financial institutions, this violates **PCI-DSS**, risks loss of certification, regulatory penalties, and could halt business operations entirely. Container hardening is a **regulatory requirement**, not an optional best practice.

---

### Your Mission

**Your Role:**  
Principal Security Engineer / Container Security Architect

**Assigned By:**  
CEO, CTO, CISO, Chief Compliance Officer, and federal banking regulators

**Mandate:**  
You have unlimited budget and **30 days** to harden all Docker containers to meet PCI-DSS requirements. The bank’s ability to process payments and maintain its license depends on your success.

---

### Objectives

You must:

- Rebuild Dockerfiles following security best practices
- Run containers as non-root users
- Drop unnecessary Linux capabilities
- Enforce CPU and memory limits
- Use read-only root filesystems
- Remove hardcoded secrets
- Apply seccomp and optional AppArmor profiles
- Integrate automated security scanning into CI/CD
- Produce compliance documentation for auditors

---

### Success Criteria

- Containers run as non-root (UID > 0)
- No privileged containers in production
- Capabilities dropped to minimum required
- CPU and memory limits enforced
- Read-only root filesystem enabled where possible
- No secrets in Dockerfiles or image layers
- Trivy scan shows no HIGH/CRITICAL issues
- Seccomp profile applied
- Resource limits prevent DoS
- PCI-DSS auditor sign-off
- Compliance documentation completed

---

## Task Description

### Lab Environment Setup

#### Provided Resources

- Docker installed and running
- Sample insecure Dockerfile
- Sample application code
- Trivy security scanner

---

### Current State (Insecure)

- Dockerfile runs application as root
- Privileged containers
- No security controls
- Vulnerable to container escape

### Target State (Secure)

- Hardened Docker image
- Non-root execution
- Minimal privileges
- PCI-DSS compliant

---

## Tasks Breakdown

---

### Task 1: Audit Current Container Security

**Objective:**  
Identify all security vulnerabilities.

**Steps:**

- Build the existing Dockerfile
- Run Trivy security scan
- Check container user (UID)
- Verify privileged execution
- Inspect Linux capabilities
- Review resource limits
- Document all findings

**Expected Outcome:**  
Complete security assessment report.

---

### Task 2: Create Non-Root User in Dockerfile

**Objective:**  
Run container as a non-root user.

**Steps:**

- Create user (e.g., `appuser`)
- Assign non-zero UID (e.g., 1000)
- Update file ownership
- Add `USER appuser` directive
- Test application
- Verify UID at runtime

**Expected Outcome:**  
Container runs as UID 1000.

---

### Task 3: Remove Hardcoded Secrets

**Objective:**  
Eliminate secrets from image layers.

**Steps:**

- Identify secrets in Dockerfile
- Remove `ENV` secrets
- Use runtime environment variables or Docker secrets
- Use multi-stage builds if needed
- Verify image history is clean

**Expected Outcome:**  
No secrets embedded in images.

---

### Task 4: Implement Resource Limits

**Objective:**  
Prevent resource exhaustion.

**Steps:**

- Set memory limit (`--memory`)
- Set CPU limit (`--cpus`)
- Configure memory reservation
- Test with `docker stats`

**Expected Outcome:**  
Container resource usage constrained.

---

### Task 5: Drop Unnecessary Capabilities

**Objective:**  
Minimize container privileges.

**Steps:**

- Run with `--cap-drop=ALL`
- Add back only required capabilities
- Remove `--privileged`
- Test application functionality

**Expected Outcome:**  
Container runs with minimal capabilities.

---

### Task 6: Implement Read-Only Root Filesystem

**Objective:**  
Prevent filesystem tampering.

**Steps:**

- Run with `--read-only`
- Add `tmpfs` mounts for writable paths
- Test application behavior

**Expected Outcome:**  
Root filesystem is immutable.

---

### Task 7: Apply Security Profiles

**Objective:**  
Restrict system calls and access.

**Steps:**

- Apply default seccomp profile
- Optionally configure AppArmor or SELinux
- Verify profile enforcement
- Test application

**Expected Outcome:**  
Security profiles active.

---

### Task 8: Security Scan and Verification

**Objective:**  
Validate hardened container.

**Steps:**

- Rebuild hardened image
- Run Trivy scan
- Confirm no HIGH/CRITICAL findings
- Verify non-root execution
- Validate resource limits
- Document results

**Expected Outcome:**  
Hardened container passes security checks.

---

## Verification Checklist

You must verify:

- Container runs as non-root (UID > 0)
- Dockerfile includes `USER` directive
- No secrets in Dockerfile or image layers
- Memory limit configured
- CPU limit configured
- All capabilities dropped (`--cap-drop=ALL`)
- No `--privileged` flag
- Read-only root filesystem enabled
- Security scan shows no HIGH/CRITICAL issues
- Application functions correctly

---

**End of Lab Assignment**
