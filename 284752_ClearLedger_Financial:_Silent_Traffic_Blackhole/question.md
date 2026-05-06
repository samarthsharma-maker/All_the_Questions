# ClearLedger Financial: Silent Traffic Blackhole

## 1. Company Background

* Company: ClearLedger Financial
* Industry: FinTech / Accounting and Payroll SaaS
* Scale: Series B startup with approximately 320 employees

Platform details:

* Multi-tenant payroll processing platform
* Handles payroll runs for more than 8,000 businesses
* Payroll execution involves several internal microservices in strict order
* Service Level Agreement: 99.9 percent uptime
* SLA penalties apply for failures during payroll processing windows
* Critical processing periods occur at end of month and every other Friday

---

## 2. The Incident

A platform engineer deployed a namespace-wide NetworkPolicy rollout to the `clearledger-prod` namespace as part of a PCI-DSS security hardening initiative.

Key timeline:

* The rollout was completed and the change ticket was closed
* No immediate alerts or visible errors appeared in monitoring dashboards
* Approximately 40 minutes later multiple alerts were triggered

Observed symptoms:

* Payroll jobs began hanging silently
* No HTTP 5xx errors were recorded
* No container crashes or restart loops occurred
* All pods remained in Running state
* Logs showed requests leaving `api-gateway` but never reaching downstream services

Connectivity failures observed:

* `payroll-worker` could not reach `tax-service`
* `tax-service` could not reach `ledger-db-proxy`
* Some pods experienced DNS lookup timeouts
* Other pods resolved DNS normally

Investigation findings:

* The NetworkPolicy rollout introduced six separate configuration mistakes
* Some policies blocked required service traffic
* Some policies allowed traffic from incorrect sources
* One required ingress rule was missing entirely
* DNS egress was misconfigured for some pods
* One namespace selector referenced a label that does not exist

Business impact:

* 2.1 hours of payroll processing downtime
* 340 payroll runs failed or stalled
* Approximately $180,000 in potential SLA penalties
* Two enterprise customers triggered regulatory audit flags
* Platform trust score dropped in the customer health dashboard

---

## 3. Architecture

All workloads run in the `clearledger-prod` namespace.

The service call chain is strictly sequential:

```
api-gateway → payroll-worker → tax-service → ledger-db-proxy
```

Monitoring architecture:

* A `prometheus` pod exists in the `monitoring` namespace
* Prometheus scrapes metrics from all services on port `9090`
* The `monitoring` namespace contains the label `purpose: monitoring`

Administrative access:

* An `admin-toolbox` pod exists in `clearledger-prod`
* Label: `app: admin-toolbox`
* Used by the SRE team for break-glass access
* Must be able to reach all services on all ports

---

## 4. Service Ports

```
| Service         | Application Port | Metrics Port |
| --------------- | ---------------- | ------------ |
| api-gateway     | 8080             | 9090         |
| payroll-worker  | 8080             | 9090         |
| tax-service     | 8443             | 9090         |
| ledger-db-proxy | 5432             | 9090         |
```

---

## 5. Environment

Resources deployed in the `clearledger-prod` namespace:

Deployments:

* `api-gateway`
* `payroll-worker`
* `tax-service`
* `ledger-db-proxy`
* `admin-toolbox`

Services:

* One ClusterIP service for each deployment
* Each service has the same name as its deployment

NetworkPolicies currently present:

* `allow-api-gateway-ingress`
* `allow-payroll-worker-ingress`
* `allow-tax-service-ingress`
* `allow-ledger-db-proxy-ingress`
* `allow-egress-dns`

Additional namespace:

* Namespace: `monitoring`
* Label: `purpose: monitoring`
* Contains a `prometheus` deployment

Known issues in the environment:

* Six configuration mistakes exist across the NetworkPolicies
* Some errors occur in ingress `from` selectors
* One problem exists in the DNS egress policy
* One required ingress rule is missing
* One namespace selector references a non-existent label

Each NetworkPolicy must be carefully inspected.

---

## 6. Your Task

Restore full connectivity between services by identifying and fixing all NetworkPolicy misconfigurations.

Requirements for the final state:

* The full service call chain must work end-to-end
* DNS resolution must function for all pods
* Prometheus must scrape metrics from all services
* The `admin-toolbox` must retain break-glass access to every service

Constraints:

* Do not delete existing NetworkPolicies
* Fix them in place or add additional policies where necessary

---

## 7. Success Criteria

1. **api-gateway ingress (port 8080)**
   Must accept traffic from any pod source because it acts as the public entry point.

2. **payroll-worker ingress (port 8080)**
   Must accept traffic only from pods labeled `app: api-gateway` in the `clearledger-prod` namespace.

3. **tax-service ingress (port 8443)**
   Must accept traffic only from pods labeled `app: payroll-worker` in the `clearledger-prod` namespace.

4. **ledger-db-proxy ingress (port 5432)**
   Must accept traffic only from pods labeled `app: tax-service` in the `clearledger-prod` namespace.

5. **metrics scraping (port 9090)**
   All services must allow ingress on port 9090 from namespaces labeled `purpose: monitoring`.

6. **admin-toolbox access**
   Pods labeled `app: admin-toolbox` must be allowed to access all services on all ports.

7. **DNS egress policy scope**
   The `allow-egress-dns` policy must apply to all pods using an empty `podSelector` (`{}`).

8. **DNS egress destination**
   Must allow TCP and UDP traffic on port 53 to the namespace labeled `kubernetes.io/metadata.name: kube-system`.

9. **monitoring namespace selector**
   Must use the namespace label `purpose: monitoring`.

10. **public ingress for api-gateway**
    The `from` field must be empty or omitted so that any source can connect.

---

## 8. Background Knowledge

### 8.1 NetworkPolicy Default-Deny Behavior

* When any NetworkPolicy selects a pod, all traffic not explicitly allowed is blocked
* Blocked traffic is silently dropped
* No TCP reset or ICMP error is returned
* The typical symptom is connection timeout rather than an explicit failure
* Pods remain in Running state and logs often appear normal

---

### 8.2 AND vs OR Behavior in `from` Rules

NetworkPolicy selectors behave differently depending on structure.

Single list item with both selectors:

```
- namespaceSelector:
- podSelector:
```

Meaning:

* The source must match both conditions

Multiple list items:

```
- namespaceSelector: ...
- podSelector: ...
```

Meaning:

* Either condition can match

This mistake frequently leads to overly permissive or overly restrictive policies.

---

### 8.3 DNS Egress and NetworkPolicies

DNS is provided by `kube-dns` running in the `kube-system` namespace.

If a policy blocks egress to:

* UDP port 53
* TCP port 53

DNS resolution will fail.

Symptoms include:

* Services cannot resolve other service names
* Pods appear healthy but cannot communicate
* Errors resemble network partitions

---

### 8.4 Namespace Selectors Match Labels

`namespaceSelector` matches namespace labels, not the namespace name.

Example mistake:

* Referencing a label that does not exist on the namespace

Verification command:

```
kubectl get namespace <namespace-name> --show-labels
```

If the label is missing, the selector matches no namespaces.

---

### 8.5 Empty `podSelector`

```
spec:
  podSelector: {}
```

Meaning:

* The policy applies to every pod in the namespace

If a selector is used such as:

```
podSelector:
  matchLabels:
    app: api-gateway
```

Then the policy applies only to that specific pod group.

An incorrectly scoped DNS policy can leave most services unable to resolve DNS.
