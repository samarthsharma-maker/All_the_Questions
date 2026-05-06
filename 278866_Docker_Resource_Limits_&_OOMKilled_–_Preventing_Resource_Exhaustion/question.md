# Docker Resource Limits & OOMKilled – Preventing Resource Exhaustion

## Context

### Company Background

**Company Name:** DataCrunch Analytics  
**Industry:** Big Data & Analytics Platform  
**Scale:** Processes ~10TB of data daily  
**Customer Base:** 5,000 enterprise customers  
**Revenue:** $150M ARR  

---

### The Incident

On Monday morning at **9:00 AM**, the entire analytics platform **crashed simultaneously**.  
All **50 containers stopped responding** within minutes.

The root cause was traced to a **single data-processing container** with a **memory leak**.  
Because no memory or CPU limits were configured, this container consumed **all 64GB of host RAM**, starving every other service.

As memory was exhausted, the Linux **OOM (Out Of Memory) killer** activated and began terminating processes indiscriminately — including the database, web servers, and critical background workers.

This resulted in a **complete platform outage lasting 6 hours**.

---

### Impact Analysis

- **6-hour complete outage**
- **$3M revenue loss** due to SLA penalties and refunds
- **5,000 customers** unable to access data
- **All 50 containers** terminated by OOM
- **3 host servers** required reboot
- **Database corruption** caused by abrupt termination
- **12 hours of data lost** (last backup was 12 hours old)
- Emergency CEO + board call
- **Largest customer (20% of ARR)** terminated contract
- Negative press coverage across tech media
- Engineering team worked **36 continuous hours**
- Stock price dropped **8%**

---

### Root Cause Summary

1. **No memory limits** on containers (unbounded RAM usage)
2. **No CPU limits** (single container monopolized CPU cores)
3. **Memory leak** in Python data-processing job
4. **No resource monitoring**
5. OOM killer terminated **critical services**, not just the faulty container

---

### Your Mission

**Role:** Senior DevOps Engineer / Site Reliability Engineer (SRE)

**Objective:**  
Prevent a single container from exhausting host resources by enforcing **memory and CPU limits**, ensuring platform stability even in the presence of faulty workloads.

---

### Success Criteria

Your solution must:

- Apply **memory limits** to containers
- Apply **CPU limits** to containers
- Demonstrate understanding of **OOMKilled behavior**
- Monitor container resource usage
- Prevent host-level resource exhaustion

---

## Tasks

### Task 1: Observe the Problem (No Limits)

- Run a container **without any resource limits**
- Simulate a memory-intensive workload
- Observe how the container can consume unlimited memory
- Identify OOM behavior when the host runs out of memory

---

### Task 2: Apply Memory Limits

- Run the container with:
  - `--memory`
  - `--memory-reservation`
- Understand the difference between:
  - **Soft limit** (reservation)
  - **Hard limit** (maximum memory)
- Verify that the container cannot exceed the configured limit

---

### Task 3: Apply CPU Limits

- Use the `--cpus` flag
- Restrict the number of CPU cores available to the container
- Prevent CPU starvation of other services

---

### Task 4: Monitor Resource Usage

- Use `docker stats` to monitor:
  - Memory usage
  - CPU usage
- Identify resource-hungry containers
- Observe behavior before and after limits are applied

---

### Task 5: Test OOMKilled Behavior

- Intentionally exhaust the container’s memory limit
- Observe container termination
- Verify:
  - Exit code **137**
  - Container marked as **OOMKilled**
- Ensure other containers remain unaffected

---

