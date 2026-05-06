# Kubernetes HPA: Multi-Tenant Autoscaling Remediation

## Company Background

**Company:** FinFlow Payments  
**Industry:** FinTech / Payment Processing  
**Scale:** High-growth startup (180 employees)

FinFlow operates a real-time payment processing platform serving 5 million active users, processing approximately 200,000 daily transactions at peak throughput of 3,000 TPS. The platform carries a 99.95% uptime SLA and a p99 latency commitment of under 200ms.

---

## The Incident

During a routine end-of-month settlement window at 11:59 PM UTC, the `payment-processor` service collapsed under a sudden 10x traffic surge. A Horizontal Pod Autoscaler was in place — it did not respond.

Post-mortem findings revealed a cascade of misconfigurations across four Kubernetes resources. The team had recently migrated to a two-container pod model (a `processor` main container and an `audit-logger` sidecar), and the sidecar's resource configuration was never completed. A `VerticalPodAutoscaler` left in `Auto` mode was found to be actively evicting pods at the same time HPA was attempting to scale out. No `PodDisruptionBudget` existed. The HPA itself had unsafe replica bounds, a misconfigured CPU target, missing metrics, and a scale-down stabilization window of zero that caused oscillation between every traffic burst.

**Business impact:**
- 47-minute payment processing outage
- $4.1M in failed or delayed transactions
- PCI-DSS SLA breach notification triggered
- 3 enterprise clients initiated contract review
- Engineering team paged at midnight for manual intervention

---

## Environment

The following resources are deployed in the `finflow-prod` namespace:

- **Deployment** `payment-processor` — two containers: `processor` (main) and `audit-logger` (sidecar)
- **HPA** `payment-processor-hpa` — targeting the above Deployment
- **VPA** `payment-processor-vpa` — present if the VPA CRD is available in the cluster
- **Service** `payment-processor` — ClusterIP on ports 8080 and 9090
- **Service** `payment-queue` — stub service representing the transaction queue, used as the custom metric source

The `processor` container currently has resource limits set (`cpu: 300m`, `memory: 256Mi`) but no requests. The `audit-logger` sidecar has no resource configuration at all. The HPA will report `<unknown>` for all metrics until this is corrected.

---

## Your Task

The autoscaling stack for `payment-processor` is broken in multiple ways. You must identify and fix every misconfiguration so that the system can safely handle production payment traffic.

---

## Success Criteria

Your solution will be evaluated against the following requirements. All must be satisfied.

```
| # | Requirement | Constraint |
|---|-------------|------------|
| 1 | `processor` container has resource requests | Both `cpu` and `memory` requests must be present |
| 2 | `audit-logger` sidecar has resource requests | Both `cpu` and `memory` requests must be present |
| 3 | HPA `minReplicas` | Must be ≥ 3 |
| 4 | HPA `maxReplicas` | Must be between 8 and 25 (inclusive) |
| 5 | HPA CPU utilization target | Must be between 60% and 85% (inclusive) |
| 6 | HPA memory utilization metric | Must be present with a target between 70% and 90% (inclusive) |
| 7 | HPA custom metric `pending_transactions` | Must be an `Object` metric with a threshold value ≤ 500 |
| 8 | VPA `updateMode` | Must be set to `Off` |
| 9 | PodDisruptionBudget | Must exist targeting `app: payment-processor` with `minAvailable` ≥ 2 |
| 10 | HPA `scaleDown.stabilizationWindowSeconds` | Must be explicitly set and ≥ 120 |
```
---

## Background Knowledge

**HPA and resource requests**  
The Kubernetes HPA calculates utilization as `(actual usage / sum of container requests) * 100`. If any container in a pod is missing resource requests, the Metrics Server cannot compute a denominator and returns `<unknown>`. This applies to every container in the pod — including sidecars.

**VPA and HPA interaction**  
Running a VPA in `Auto` or `Recreate` mode alongside an HPA that targets the same resource metrics (CPU/memory) is a known anti-pattern. VPA will evict pods to right-size them vertically at the exact moment HPA is trying to scale out horizontally, producing a destructive eviction loop. Setting VPA to `Off` mode preserves its right-sizing recommendations without triggering any evictions.

**Custom metrics for queue-based workloads**  
CPU utilization is a lagging indicator for transaction queue workloads. By the time CPU saturates, thousands of payments are already backed up. Scaling on `pending_transactions` directly allows the HPA to react proactively before latency degrades.

**PodDisruptionBudgets**  
A PDB is the contract between an application and the Kubernetes control plane during voluntary disruptions such as node drains and rolling updates. Without one, Kubernetes has no obligation to keep any pods running during maintenance operations.

**ScaleDown stabilization**  
A `stabilizationWindowSeconds` of zero causes HPA to scale down the moment load drops, then scale back up when the next burst hits seconds later — a classic oscillation pattern that wastes pod scheduling capacity and increases p99 latency.