# NimbusFlow AI: Silent Deployments, Destructive Syncs, and Missing Alerts

## 1. Company Background

* **Company:** NimbusFlow AI
* **Industry:** Machine Learning Infrastructure / Inference Platform SaaS
* **Scale:** Series A startup with approximately 60 engineers

Platform details:

* ML inference workloads run on Kubernetes, managed via ArgoCD (v2.9)
* GitOps workflow: all application manifests live in a Gitea repository
* One ArgoCD project: `nimbusflow-prod`, with a deny sync window to
  protect business hours from disruptive deployments
* The `inference-api` Application serves live model inference traffic
  and uses Server-Side Apply to safely manage controller-owned fields
* ArgoCD Notifications alerts the on-call Slack channel on every sync
  failure so engineers can respond before customers are impacted
* Image update annotations on Applications let the ArgoCD Image Updater
  automatically track and apply new container image tags from the registry
* SLA: zero unplanned downtime during business hours (09:00–18:00 UTC)

---

## 2. The Incident

A platform engineer applied a "GitOps housekeeping" change covering the
ArgoCD project sync window, the `inference-api` Application sync options,
and the ArgoCD Notifications ConfigMap.

Key timeline:

* Changes applied and committed; change ticket closed as successful
* No immediate errors were visible
* The following morning, a Git push carrying a critical model patch
  did not deploy — ArgoCD showed the Application as `OutOfSync`
  but automated sync never triggered
* During a manual sync attempt, the `inference-api` Deployment was
  replaced wholesale — a field managed by the HPA controller was wiped,
  causing the HPA to crash-loop and replica count to drop to 1
* A sync failure on a separate application fired no Slack notification —
  the on-call engineer only discovered it during a routine check 40 minutes
  later

Investigation findings:

* Three separate misconfigurations were introduced by the batch change
* The `nimbusflow-prod` project's deny sync window used a schedule of
  `* * * * *` — blocking all automated syncs 24 hours a day, 7 days a week
* The `inference-api` Application had `Replace=true` in its syncOptions,
  causing ArgoCD to run `kubectl replace` (full resource replacement)
  instead of a safe server-side patch
* The ArgoCD Notifications trigger for sync failures referenced a template
  name that did not match any defined template — every failure notification
  was silently dropped

Business impact:

* Critical model patch blocked for 6 hours — inference accuracy degraded
* HPA crash-loop caused inference-api replica count to floor at 1 during
  peak traffic — p99 latency spiked to 22 seconds
* 40-minute gap in alerting coverage — one sync failure went undetected
* Two enterprise customers filed support tickets citing inference quality
  issues

---

## 3. Architecture

ArgoCD is installed in the `argocd` namespace on a K3s cluster.

ArgoCD Project:

```
| Project          | Allowed repos                               | Sync window |
| ---------------- | ------------------------------------------- | ----------- |
| nimbusflow-prod  | http://localhost:3000/judge/nimbusflow-manifests | deny during off-hours maintenance |
```

ArgoCD Application:

```
| Application   | Project         | Namespace | Sync options         |
| ------------- | --------------- | --------- | -------------------- |
| inference-api | nimbusflow-prod | inference | ServerSideApply=true |
```

ArgoCD Notifications:

```
| Trigger         | Condition             | Template          |
| --------------- | --------------------- | ----------------- |
| on-sync-failed  | app.status sync failed | app-sync-failed   |
```

Image Updater annotation on `inference-api`:

```
argocd-image-updater.argoproj.io/image-list: inference=nimbusflow/inference-api
argocd-image-updater.argoproj.io/inference.update-strategy: semver
```

Lab files: `/home/user/nimbusflow-argocd-lab/`
Environment info: `/home/user/imp_info.txt`
KUBECONFIG: `/etc/rancher/k3s/k3s.yaml`

---

## 4. Known Issues

Three configuration mistakes exist across the environment:

* One mistake in the `nimbusflow-prod` AppProject sync window schedule
* One mistake in the `inference-api` Application syncOptions
* One mistake in the `argocd-notifications-cm` ConfigMap trigger definition

---

## 5. Your Task

Restore full GitOps operation by identifying and fixing all three misconfigurations.

Requirements for the final state:

* The `nimbusflow-prod` project deny window must only block syncs during
  business hours — `0 9 * * 1-5` (09:00 Mon–Fri), duration 9 hours.
  Syncs outside business hours must be allowed.
* The `inference-api` Application must use `ServerSideApply=true` instead
  of `Replace=true` so controller-managed fields are never wiped.
* The `argocd-notifications-cm` trigger `on-sync-failed` must reference
  the template named `app-sync-failed` (not `app-sync-failed-notify`).

Constraints:

* Do not delete the sync window — only correct its schedule
* Do not remove syncOptions entirely — replace `Replace=true` with
  `ServerSideApply=true`
* Do not rename the template — only fix the trigger's reference to it

---

## 6. Success Criteria

1. **AppProject sync window — correct schedule**
   The `nimbusflow-prod` project's deny sync window must have schedule
   `0 9 * * 1-5`. The broken schedule `* * * * *` matches every minute
   of every day — no automated sync can ever proceed regardless of when
   it is triggered.

2. **inference-api syncOptions — ServerSideApply**
   The `inference-api` Application must have `ServerSideApply=true` in
   its `syncOptions` list and must NOT have `Replace=true`. With
   `Replace=true`, ArgoCD calls `kubectl replace` which reconstructs the
   entire resource from the manifest, wiping any fields not present in Git
   — including fields written by controllers such as the HPA's
   `currentReplicas` status field and injected sidecar annotations.

3. **Notifications trigger — correct template name**
   The `on-sync-failed` trigger in `argocd-notifications-cm` must send
   template `app-sync-failed`. The broken config sends
   `app-sync-failed-notify` — a name that has no matching template
   definition in the ConfigMap. The notifications controller resolves
   template names at send time; a missing template causes the notification
   to be silently dropped with no error surfaced to the user.

---

## 7. Background Knowledge

### 7.1 ArgoCD Sync Windows

Sync windows are defined on AppProject resources and control when
automated (and optionally manual) syncs are permitted.

```yaml
syncWindows:
  - kind: deny          # 'allow' or 'deny'
    schedule: "0 9 * * 1-5"   # standard cron — when the window is ACTIVE
    duration: 9h
    applications:
      - '*'
    manualSync: false
```

A `deny` window is **active** during the cron schedule. While active,
automated syncs matching the window's application selector are blocked.

Critical detail: `* * * * *` means the window is active at **every
minute of every day** — a deny window with this schedule permanently
blocks all automated syncs. The intended schedule `0 9 * * 1-5` activates
the deny window once per weekday at 09:00, staying active for `duration`.

---

### 7.2 Replace=true vs ServerSideApply=true

`Replace=true`:
- ArgoCD calls `kubectl replace` — sends the full manifest as a replacement
- Any field not in the Git manifest is **deleted** from the live resource
- Controller-managed fields (HPA replicas, injected sidecars, admission
  webhook annotations) are wiped on every sync
- Can cause brief resource recreation (downtime for Deployments)

`ServerSideApply=true`:
- ArgoCD calls `kubectl apply --server-side`
- Only fields owned by ArgoCD's field manager are updated
- Fields owned by other controllers (HPA, cert-manager, etc.) are untouched
- Safe for resources shared between ArgoCD and other controllers

---

### 7.3 ArgoCD Notifications — Triggers and Templates

ArgoCD Notifications config lives in `argocd-notifications-cm` in the
`argocd` namespace. A trigger defines **when** to send; a template defines
**what** to send.

```yaml
data:
  trigger.on-sync-failed: |
    - when: app.status.operationState.phase in ['Error', 'Failed']
      send: [app-sync-failed]        # ← must match a template name exactly

  template.app-sync-failed: |
    message: |
      Application {{.app.metadata.name}} sync failed.
```

If `send: [app-sync-failed-notify]` is set but only `template.app-sync-failed`
is defined, the controller logs a "template not found" error internally
and drops the notification — no message is ever sent to Slack or any
other destination. The trigger fires but produces no output.

---

### 7.4 ArgoCD Image Updater Annotations

The ArgoCD Image Updater reads annotations on Application resources to
determine which images to track and how to update them.

```yaml
annotations:
  argocd-image-updater.argoproj.io/image-list: <alias>=<registry>/<image>
  argocd-image-updater.argoproj.io/inference.update-strategy: semver
```

The `update-strategy` annotation key must use the image alias as a prefix
(`<alias>.update-strategy`). If the alias in `image-list` is `inference`
but the strategy annotation uses a different prefix, the updater applies
its default strategy (`:latest` digest) instead of the intended `semver`
tracking — potentially deploying pre-release or unstable tags.

---

### 7.5 Debugging Commands

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Check sync window on the project
kubectl get appproject nimbusflow-prod -n argocd -o yaml

# Check inference-api syncOptions
kubectl get application inference-api -n argocd -o yaml

# Check notifications ConfigMap
kubectl get configmap argocd-notifications-cm -n argocd -o yaml

# Check image updater annotations on the Application
kubectl get application inference-api -n argocd \
  -o jsonpath='{.metadata.annotations}'
```