# VaultStream Analytics: Silent Runtime Failures

## Company Background

**Company:** VaultStream Analytics  
**Industry:** SaaS / Real-time Data Pipeline  
**Scale:** Series A startup (140 employees)

VaultStream operates a real-time event processing platform that ingests, transforms, and routes financial telemetry data for institutional clients. Each component in the pipeline reads its runtime configuration from Kubernetes ConfigMaps and Secrets. The platform has a strict data-loss SLA: no event may be silently dropped without an audit log entry.

---

## The Incident

A junior engineer completed a sprint task to "migrate all hardcoded environment variables to ConfigMaps and Secrets." The PR was approved and merged. CI passed. The rollout completed with all pods showing `Running` and `Ready`.

Forty-five minutes into the next business hour, the data pipeline began silently dropping events. No pods crashed. No OOMKilled. No image pull errors. Readiness probes passed. The monitoring dashboard showed pod counts as healthy.

Investigation revealed that several pods were starting with wrong, empty, or missing configuration values. One pod was reading a database password from the wrong key. Another had its entire config volume mounted at the wrong path, causing the application to fall back to built-in defaults silently. A third service was failing to connect to its upstream broker because the ConfigMap it referenced did not exist in the correct namespace. A Secret was created with a value that was double-base64-encoded, causing the application to receive garbled credentials. A deployment was mounting a Secret as a volume but the Secret had been created in a different namespace. One ConfigMap key was being injected as an environment variable under the wrong name, so the application read an empty string.

**Business impact:**
- 3.5 hours of silent data loss before detection
- 2.1 million events dropped with no audit trail
- Two institutional clients triggered SLA breach reviews
- Engineering team spent 11 hours on post-mortem and manual data replay
- Regulatory reporting window missed for one client

---

## Architecture

All workload resources live in the `vaultstream-prod` namespace. The pipeline is linear:

```
event-ingestor  →  transform-worker  →  route-dispatcher  →  audit-logger
```

Each service depends on a combination of ConfigMaps and Secrets for:
- Database connection strings and credentials
- Upstream broker addresses
- Feature flags and tuning parameters
- TLS certificate paths

---

## Environment

The following resources are deployed in `vaultstream-prod`:

- **Deployments**: `event-ingestor`, `transform-worker`, `route-dispatcher`, `audit-logger`
- **ConfigMaps**: `ingestor-config`, `worker-config`, `dispatcher-config`, `pipeline-feature-flags`
- **Secrets**: `db-credentials`, `broker-tls-secret`, `audit-signing-key`
- **Namespace**: `vaultstream-prod`

Six things are wrong. The bugs span: wrong Secret key references, double-base64-encoded Secret values, a ConfigMap referenced from the wrong namespace, a volume mounted at the wrong path, an environment variable injected under the wrong key name, and a ConfigMap key that does not exist in the referenced ConfigMap.

---

## Your Task

Identify and fix all six misconfigurations so the full pipeline starts with correct runtime configuration. All pods must read the values they expect, from the correct sources, under the correct names.

Do not delete any Deployment. Fix ConfigMaps, Secrets, and Deployment specs in place.

---

## Success Criteria
1. **db-credentials Secret encoding**
   The value for key `password` in the `db-credentials` Secret must be correctly base64 encoded and must decode to a valid non-empty string without requiring a second decode step.

2. **event-ingestor database password reference**
   The `event-ingestor` must read the database password from the Secret key `password` using `valueFrom.secretKeyRef.key`.

3. **worker-config ConfigMap key**
   The `worker-config` ConfigMap must contain the key `broker_address` with a non-empty value.

4. **transform-worker environment variable**
   The `transform-worker` Deployment must inject the `broker_address` value as the environment variable `BROKER_ADDRESS`.

5. **route-dispatcher config volume mount**
   The configuration volume for `route-dispatcher` must be mounted at `/etc/dispatcher`.

6. **broker-tls-secret namespace**
   The Secret `broker-tls-secret` must exist in the `vaultstream-prod` namespace.

7. **route-dispatcher Secret reference**
   The `route-dispatcher` must reference the `broker-tls-secret` Secret within the same `vaultstream-prod` namespace.

8. **audit-logger signing key reference**
   The `audit-logger` must read the `SIGNING_KEY` from the Secret `audit-signing-key` using the key `signing_key`.

9. **pipeline-feature-flags ConfigMap key**
   The `pipeline-feature-flags` ConfigMap must contain the key `enable_audit_log` with the value `"true"`.

10. **audit-logger audit log flag injection**
    The `audit-logger` must inject the `enable_audit_log` value as the environment variable `ENABLE_AUDIT_LOG` using `configMapKeyRef.key: enable_audit_log`.

---

## Background Knowledge

**Double base64 encoding in Secrets**
Kubernetes Secrets store values as base64. When you create a Secret using `kubectl apply` with a YAML manifest, the `data` field expects values that are already base64-encoded. If you base64-encode a value and then paste it into a manifest that `kubectl` then base64-encodes again, the pod receives a base64 string as its value instead of the original plaintext. The application sees garbled credentials with no error from Kubernetes — the Secret is healthy, the pod is running, the value is simply wrong.

**secretKeyRef and configMapKeyRef key mismatches**
When a Deployment references a Secret or ConfigMap key that does not exist, the pod fails to start with `CreateContainerConfigError`. But when the key exists but is the wrong one (e.g. `passwd` instead of `password`), the pod starts successfully and the application receives a different value or an empty string — silently.

**Volume mountPath vs application expectation**
A volume can be mounted successfully at any path. Kubernetes does not validate that the path matches what the application expects. If a ConfigMap is mounted at `/etc/config` but the application reads from `/etc/dispatcher`, the application silently reads nothing and falls back to defaults. The pod shows `Running` and `Ready`.

**ConfigMap key existence**
A `configMapKeyRef` that references a key not present in the ConfigMap causes `CreateContainerConfigError` and the pod will not start. However a ConfigMap that is missing a key entirely — where the Deployment references it — is caught at pod scheduling time, not at apply time. The error only surfaces when the pod tries to start.

**Cross-namespace Secret references**
Kubernetes Secrets and ConfigMaps are namespace-scoped. A Deployment in `vaultstream-prod` cannot reference a Secret or ConfigMap from another namespace via a volume or `envFrom`. If the Secret exists only in a different namespace, the pod will fail with `secret not found` — but if you are not watching pod events closely, this can look identical to a transient scheduling delay.