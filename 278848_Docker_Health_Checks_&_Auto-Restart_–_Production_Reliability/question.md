## Docker Health Checks & Auto-Restart – Production Reliability


## Context

### Company Background

- **Company Name:** CloudCart Commerce
- **Industry:** E-commerce Platform
- **Scale:** Mid-size SaaS (350 employees)
- **Core Business:**
  - Online shopping platform
  - 40,000 active merchants
  - 3 million daily users
  - Flash-sale driven traffic spikes
  - 99.9% uptime SLA with merchants

---

### The Incident

**What happened:**  
During a major flash sale event, the `checkout-service` container continued to show as **RUNNING** in Docker, but customers were unable to place orders. The application inside the container had **frozen due to a deadlock**, but Docker did not restart it.

The service stayed in this broken state for **47 minutes** before engineers manually intervened.

**Why this happened:**  
- No `HEALTHCHECK` was defined in the Docker image  
- Docker had no way to detect the application was unresponsive  
- Restart policy was set to `no`  
- Monitoring only checked container state, not application health  

---

### Business Impact

- Checkout unavailable during peak traffic
- ₹3.2 crore (~$400K) revenue loss
- 18,000 failed transactions
- SLA breach with enterprise merchants
- Customer complaints on social media
- Emergency incident bridge for 2 hours
- Engineering confidence shaken
- CTO escalated incident as a reliability failure

---

### Symptoms Observed

- `docker ps` showed container as **Up**
- Application endpoint `/health` stopped responding
- No container restarts occurred
- Logs stopped progressing
- CPU usage dropped to near zero
- Monitoring falsely reported system as healthy
- Manual restart immediately fixed the issue

---

### Root Cause Analysis

**Primary Cause:**  
The container had **no HEALTHCHECK**, so Docker assumed the container was healthy as long as the process existed.

**Contributing Factors:**

- Misunderstanding that “RUNNING” ≠ “HEALTHY”
- No application-level health probe
- Inadequate restart policy
- Overreliance on infrastructure metrics
- No chaos testing or failure simulation
- Health checks not enforced in CI/CD
- Lack of production readiness checklist

---

### Why This Matters

In production systems:
- Containers can be alive but **functionally dead**
- Deadlocks, memory exhaustion, or thread starvation won’t crash processes
- Docker will NOT restart containers unless health checks fail

Health checks combined with restart policies:
- Enable **self-healing**
- Reduce MTTR
- Prevent silent outages
- Are a foundational reliability practice

---

## Your Mission

**Your Role:**  
Site Reliability Engineer / Platform Engineer

**Assigned By:**  
CTO & Head of Engineering

**Mandate:**  
Fix the reliability issue by implementing **application health checks and automatic recovery**.

---

## Objectives

You must:

- Add a `HEALTHCHECK` to the Docker image
- Ensure the application exposes a health endpoint
- Configure Docker restart policies correctly
- Demonstrate auto-recovery when the app becomes unresponsive
- Validate health-based restarts using test scripts

---

## Success Criteria

- Container reports `healthy` when app is responsive
- Container reports `unhealthy` when app freezes
- Docker automatically restarts unhealthy container
- Restart policy survives Docker daemon restart
- No manual intervention required
- Health-based monitoring is demonstrable

---

## Task Description

### Current State (Broken)

- Container runs a web app on port 8080
- App can intentionally freeze
- No HEALTHCHECK defined
- Restart policy set to `no`
- Docker cannot detect failures

### Target State (Resilient)

- HEALTHCHECK defined in Dockerfile
- Restart policy set to `unless-stopped`
- Docker restarts container automatically
- Health state visible via `docker ps`

---

### Tasks Breakdown

#### Task 1: Inspect Current Container Behavior
- Run the container
- Verify it shows as `Up`
- Simulate application freeze
- Confirm Docker does NOT restart it

#### Task 2: Add Application Health Endpoint
- Expose `/health` endpoint
- Ensure it fails when app is frozen

#### Task 3: Implement Docker HEALTHCHECK
- Add HEALTHCHECK in Dockerfile
- Configure interval, timeout, retries
- Use curl or wget to test `/health`

#### Task 4: Configure Restart Policy
- Use `restart: unless-stopped`
- Ensure container restarts on failure

#### Task 5: Validate Auto-Recovery
- Simulate app freeze
- Observe container becoming `unhealthy`
- Confirm Docker restarts it automatically

---

## Verification Checklist

- `docker inspect` shows HEALTHCHECK configured
- `docker ps` shows `(healthy)`
- Container restarts after becoming unhealthy
- Restart count increments automatically
- No manual restart required

---

**End of Lab Assignment**
