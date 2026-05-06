# RetailPulse: Silent Metrics and a Fleet That Wouldn’t Scale

## 1. Company Background

**Company:** RetailPulse Analytics
**Industry:** E-Commerce Analytics SaaS
**Scale:** Series B startup with ~180 employees

Platform details:

* Backend runs on a fleet of EC2 instances managed by an Auto Scaling Group
* Instances run the **Amazon CloudWatch Agent** to publish memory metrics
* CloudWatch alarms notify engineers when memory usage becomes unhealthy
* The infrastructure automatically scales based on application request load
* Region used by the platform: **`us-west-2`**
* SLA: **99.9% uptime during peak retail hours**

RetailPulse customers rely on the platform to generate **real-time analytics dashboards** during major retail events such as:

* Black Friday
* End-of-month reporting windows
* Holiday promotions

Maintaining **observability and responsive scaling** is critical during these periods.

---

# 2. The Incident

During a routine maintenance window, a DevOps engineer attempted to standardize the platform’s monitoring configuration.

The change included updates to:

* EC2 IAM permissions
* CloudWatch Agent configuration
* CloudWatch alarms
* Auto Scaling target tracking policy

The update appeared successful and the change request was closed.

However, the following morning during peak traffic hours, several issues surfaced:

* Memory alarms never triggered
* Memory metrics disappeared from CloudWatch dashboards
* Infrastructure did not scale even as request traffic increased
* On-call engineers received no alerts despite rising resource pressure

---

## Investigation Findings

The root cause was traced to **four independent misconfigurations introduced in the batch change**.

### 1. IAM Permission Missing

The EC2 instance role lacked the permission required for the CloudWatch Agent to publish metrics.

### 2. CloudWatch Namespace Mismatch

The CloudWatch Agent configuration pushed metrics to the wrong namespace.

### 3. Alarm Evaluation Delay

The memory alarm required **12 evaluation periods**, causing alerts to trigger far too late.

### 4. Incorrect Auto Scaling Metric

The Auto Scaling policy tracked **CPU utilization instead of request load**, preventing proactive scaling.

---

## Business Impact

* Monitoring visibility degraded for **several hours**
* Memory metrics disappeared from dashboards
* Alerts did not trigger when memory usage increased
* Auto Scaling failed to react to increased request traffic
* Response latency increased during peak demand

Although the incident did not cause a full outage, it exposed serious **observability and scaling reliability gaps**.

---

# 3. Architecture

**Region:** `us-west-2`
**Account ID:** Determined dynamically via:

```
aws sts get-caller-identity
```

---

## EC2 Infrastructure

Auto Scaling Group:

```
retailpulse-app-asg
```

Launch Template:

```
retailpulse-lt
```

Instance IAM Role:

```
retailpulse-ec2-role
```

Inline policy name:

```
retailpulse-cloudwatch-policy
```

---

## CloudWatch Components

CloudWatch Agent config location:

```
/opt/aws/amazon-cloudwatch-agent/bin/config.json
```

Correct metric namespace:

```
RetailPulse/AppMetrics
```

Broken namespace:

```
RetailPulseMetrics
```

---

## CloudWatch Alarm

Alarm name:

```
retailpulse-high-memory
```

Metric monitored:

```
mem_used_percent
```

Correct configuration:

```
evaluation-periods = 2
```

Broken configuration:

```
evaluation-periods = 12
```

---

## Auto Scaling

Scaling policy:

```
retailpulse-target-tracking
```

Correct metric:

```
RequestsPerTarget
Namespace: AWS/ApplicationELB
```

Broken metric:

```
ASGAverageCPUUtilization
```

---

## Lab Files

Working directory:

```
/home/user/retailpulse-lab/
```

Environment details file:

```
/home/user/imp_info.txt
```

---

# 4. CloudWatch Agent IAM Requirements

For the CloudWatch Agent to publish metrics successfully, the EC2 instance IAM role must include:

```
cloudwatch:PutMetricData
ec2:DescribeVolumes
ec2:DescribeTags
```

Without `cloudwatch:PutMetricData`, the agent continues running normally but **no metrics are published to CloudWatch**.

This makes the failure difficult to detect because **logs show no errors while dashboards display no data**.

---

# 5. Known Issues

The environment currently contains **four configuration problems**:

1. IAM policy missing permission for metric publishing
2. CloudWatch Agent publishing metrics to the wrong namespace
3. CloudWatch alarm evaluation period set too high
4. Auto Scaling policy tracking the wrong metric

Each issue contributes to the overall observability failure.

---

# 6. Your Task

Restore the platform’s monitoring and scaling behavior by fixing all misconfigurations.

Your goal is to ensure:

* CloudWatch Agent successfully publishes metrics
* Memory metrics appear in the correct namespace
* CloudWatch alarms trigger promptly
* Auto Scaling reacts to application traffic rather than CPU saturation

---

# 7. Success Criteria

## 1 — IAM Policy Fix

The inline policy:

```
retailpulse-cloudwatch-policy
```

must include:

```
cloudwatch:PutMetricData
```

This allows the CloudWatch Agent to publish metrics.

---

## 2 — CloudWatch Agent Namespace

The agent configuration must publish metrics under:

```
RetailPulse/AppMetrics
```

instead of the incorrect namespace:

```
RetailPulseMetrics
```

---

## 3 — Alarm Evaluation Period

The alarm:

```
retailpulse-high-memory
```

must use:

```
evaluation-periods = 2
```

instead of the incorrect value:

```
evaluation-periods = 12
```

This ensures alerts trigger promptly when memory usage becomes unhealthy.

---

## 4 — Auto Scaling Metric

The scaling policy:

```
retailpulse-target-tracking
```

must track:

```
MetricName: RequestsPerTarget
Namespace: AWS/ApplicationELB
```

instead of:

```
ASGAverageCPUUtilization
```

Request-based scaling reacts **earlier than CPU-based scaling**, preventing instance saturation during traffic spikes.

---

# 8. Background Knowledge

## 8.1 Why Memory Metrics Require the CloudWatch Agent

AWS hypervisors can only observe metrics outside the guest operating system.

Visible to the hypervisor:

* CPU utilization
* Network traffic
* Disk I/O

Not visible to the hypervisor:

* Memory usage
* Disk space utilization
* Swap usage

To collect these metrics, the **CloudWatch Agent runs inside the instance OS** and publishes them using the `PutMetricData` API.

If IAM permissions are missing, the agent runs normally but **CloudWatch receives no metrics**.

---

## 8.2 CloudWatch Metric Namespaces

CloudWatch organizes metrics using namespaces.

Examples:

```
AWS/EC2
AWS/ApplicationELB
Custom namespaces
```

The CloudWatch Agent publishes metrics under the namespace defined in its configuration file.

If the namespace is incorrect, metrics appear under a **different namespace than the dashboards and alarms expect**, causing monitoring to appear broken even though metrics are being published.

---

## 8.3 Alarm Evaluation Periods

CloudWatch alarms evaluate metrics over multiple periods.

Example:

```
evaluation-periods = 2
period = 300 seconds
```

This means the alarm triggers after **two consecutive five-minute periods** exceeding the threshold.

Using a large evaluation period such as **12** delays alerting significantly and reduces responsiveness during incidents.

---

## 8.4 Request-Based Auto Scaling

CPU-based scaling reacts **after instances are already under pressure**.

Traffic-based scaling reacts **as soon as request load increases**.

Metric:

```
RequestsPerTarget
```

Advantages:

* Earlier scaling decisions
* Reduced request latency
* Better handling of burst traffic

For request-driven services, scaling based on **request load** is generally more effective than CPU utilization.

---
