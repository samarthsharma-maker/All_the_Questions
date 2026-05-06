# FinTechPay Systems Docker Img Harderning

---

## Context

### Company Background

- **Company Name:** FinTechPay Systems
- **Industry:** Payments & Financial Technology
- **Scale:** Mid-sized fintech (1,200 employees)
- **Core Business:**
  - Payment processing APIs
  - Fraud detection services
  - Merchant integrations
- **Daily Volume:**
  - 20 million API requests
  - $3B in daily transactions
- **Compliance Requirements:**
  - PCI-DSS
  - SOC 2
  - ISO 27001

---

## The Problem

During a routine internal security review, the platform security team identified that multiple production services are built using **single-stage Docker images** that:

- Use large base images (e.g., `python:latest`)
- Run applications as `root`
- Contain build tools in the final image
- Have unnecessary OS packages installed
- Result in large image sizes and slow deployments
- Increase the attack surface unnecessarily

A recent outage highlighted that:

- Image pull times were slow during auto-scaling
- Containers had more privileges than required
- Vulnerabilities were detected in unused build dependencies

---

## Business Impact

- Slower container startup times
- Increased infrastructure costs
- Larger security attack surface
- Failed internal security benchmarks
- Increased vulnerability exposure
- Compliance audit concerns
- Reduced confidence in deployment safety

The platform team has mandated that **all application images must use multi-stage builds** and follow **Docker hardening best practices**.

---

## Why This Matters

Using single-stage Docker builds for applications introduces multiple risks:

- Build tools remain in production images
- Larger images mean slower deployments and rollbacks
- More packages increase vulnerability count
- Running as root increases blast radius of exploits

Multi-stage builds allow teams to:

- Separate build-time and runtime dependencies
- Reduce image size significantly
- Improve security posture
- Align with industry best practices

---

## Your Role

**Role:** Senior DevOps / Platform Engineer

**Responsibility:**

You are responsible for improving container build quality across the organization by:

- Introducing multi-stage Docker builds
- Applying least-privilege principles
- Optimizing image size
- Ensuring runtime safety

---

## Application Overview

You are given a **simple Python web application**.

### Application Details

- Language: Python 3
- Framework: Flask
- Exposes HTTP endpoint on port `8080`
- Uses `requirements.txt` for dependencies
- Application entrypoint: `app.py`

---

## Current State (Insecure)

The current Docker setup has the following issues:

- Single-stage Dockerfile
- Uses `python:latest`
- Installs build tools in final image
- Runs application as root
- No separation between build and runtime layers
- Large image size
- No clear distinction between dev and prod concerns

---

## Target State (Secure & Optimized)

The final Docker image must:

- Use a **multi-stage Docker build**
- Separate build dependencies from runtime image
- Use a minimal runtime base image
- Run the application as a non-root user
- Contain only required runtime files
- Expose only the required port
- Start the application reliably

---

## Tasks Breakdown

---

### Task 1: Analyze the Existing Dockerfile

**Objective:**  
Understand current problems and inefficiencies.

**Steps:**

- Review the existing Dockerfile
- Identify security and performance issues
- Note image size and unnecessary components
- Document findings

**Expected Outcome:**  
Clear understanding of why the current image is suboptimal.

---

### Task 2: Design a Multi-Stage Dockerfile

**Objective:**  
Separate build and runtime concerns.

**Steps:**

- Use a builder stage to install dependencies
- Compile or prepare Python dependencies if required
- Copy only necessary artifacts into the final stage
- Ensure no build tools remain in the runtime image

**Expected Outcome:**  
A functional multi-stage Dockerfile.

---

### Task 3: Minimize the Runtime Image

**Objective:**  
Reduce attack surface and image size.

**Steps:**

- Choose a minimal base image for runtime
- Remove unnecessary packages
- Copy only application code and dependencies
- Avoid debug or development tools

**Expected Outcome:**  
Lean production-ready image.

---

### Task 4: Run Application as Non-Root

**Objective:**  
Apply least privilege principles.

**Steps:**

- Create a non-root user in the Dockerfile
- Set correct file ownership
- Use `USER` directive
- Verify application runs correctly

**Expected Outcome:**  
Container runs with a non-zero UID.

---

### Task 5: Validate the Build

**Objective:**  
Ensure correctness and stability.

**Steps:**

- Build the Docker image
- Run the container locally
- Verify application is reachable
- Check container user
- Confirm application logs are correct

**Expected Outcome:**  
Working container with secure defaults.

---

## Success Criteria

The solution is considered correct if:

- Dockerfile uses **multi-stage build**
- Build tools do **not** exist in final image
- Application runs successfully
- Image size is significantly reduced
- Container runs as non-root
- Only required files exist in runtime image
- No unnecessary packages are installed

---

## Verification Checklist

You should be able to verify:

- `docker history` shows clean separation of stages
- `docker image inspect` confirms non-root user
- Image size reduced compared to original
- Application responds on expected port
- No build dependencies present in runtime image

---

## Deliverables

- Updated multi-stage `Dockerfile`
- Brief explanation of design choices
- Validation steps used to confirm correctness

---

**End of Assignment**
