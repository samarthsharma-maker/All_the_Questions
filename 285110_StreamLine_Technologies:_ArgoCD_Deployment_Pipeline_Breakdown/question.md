# StreamLine Technologies: ArgoCD Deployment Pipeline Breakdown

## 1. Company Background

* **Company:** StreamLine Technologies
* **Industry:** DevOps Tooling / CI-CD Platform SaaS
* **Scale:** Series A startup with approximately 90 employees

Platform details:

* Applications are deployed to Kubernetes via ArgoCD (v2.9)
* GitOps workflow: all manifests live in a central Git repository
* Two ArgoCD projects: `staging` and `production`
* Two teams: `frontend-team` and `backend-team`
* Each team manages their own ArgoCD Application resources
* Automated sync with self-healing is used to enforce GitOps compliance
* PostSync hook Jobs run database migrations after every successful deployment
* SLA: deployments must complete within 10 minutes of a Git push during business hours

---

## 2. The Incident

A platform engineer applied a "GitOps hardening" batch change. The change touched ArgoCD
RBAC ConfigMaps, Application sync policies, and a PostSync hook Job annotation.

Key timeline:

* Changes applied and pushed to the cluster
* Change ticket closed as successful
* Within the next deployment cycle, three separate failures surfaced

Observed symptoms:

* The `john_doe` user was unable to sync or manage `frontend-app`
  despite having a role binding in place
* A manual change was applied directly to the `staging` cluster (config drift).
  ArgoCD detected the drift but did not automatically reconcile it
* A PostSync database migration Job failed on one deployment.
  Every subsequent sync of that application was blocked with
  `ComparisonError: too many resources`

Investigation findings:

* Three separate misconfigurations were introduced
* The `frontend-team` RBAC role binding referenced the wrong ArgoCD project
* The `api-server` Application's sync policy had `selfHeal` disabled
* The `db-migrate` PostSync hook had a deletion policy that kept failed Jobs
  instead of cleaning them up — causing hook accumulation that blocked future syncs

Business impact:

* `frontend-team` locked out of deployments for 2.5 hours
* Config drift on `staging` went unreconciled — a debug flag was accidentally
  left enabled in production-equivalent staging for 4 hours
* 6 deployment attempts for `api-server` blocked by accumulated failed hook Jobs
* Two on-call engineers spent 3 hours debugging

---

## 3. Architecture

ArgoCD is installed in the `argocd` namespace.

ArgoCD Projects:

```
| Project    | Allowed source repos         | Allowed destinations      |
| ---------- | ---------------------------- | ------------------------- |
| staging    | https://github.com/streamline/k8s-manifests | staging cluster / *  |
| production | https://github.com/streamline/k8s-manifests | production cluster / * |
```

ArgoCD Applications:

```
| Application    | Project    | Namespace   | Managed by      |
| -------------- | ---------- | ----------- | --------------- |
| frontend-app   | staging    | frontend    | frontend-team   |
| api-server     | staging    | backend     | backend-team    |
```

ArgoCD RBAC roles:

```
| Role                          | Permissions                                      |
| ----------------------------- | ------------------------------------------------ |
| role:frontend-deployer        | sync, get, create, update apps in project staging |
| role:backend-deployer         | sync, get, create, update apps in project staging |
```

User bindings:

```
| User      | Role                    |
| --------- | ----------------------- |
| john_doe  | role:frontend-deployer  |
| admin     | role:backend-deployer   |
```

Lab files location: `/home/user/streamline-argocd-lab/`
Environment info: `/home/user/imp_info.txt`
Gitea repo: `http://localhost:3000/judge/streamline-manifests`
KUBECONFIG: `/etc/rancher/k3s/k3s.yaml`

---

## 4. Resources in the Environment

**ConfigMap — RBAC policy:**
* Name: `argocd-rbac-cm`
* Namespace: `argocd`

**Application manifests (as YAML files in the lab directory):**
* `frontend-app.yaml` — the ArgoCD Application for the frontend team
* `api-server.yaml` — the ArgoCD Application for the backend team

**Hook Job manifest:**
* `db-migrate-hook.yaml` — PostSync Job with hook deletion policy annotation

All three files are written to `/home/user/streamline-argocd-lab/` by the setup
script and applied to the cluster with `kubectl apply`.

---

## 5. Known Issues

Three configuration mistakes exist across the environment:

* One mistake in the ArgoCD RBAC ConfigMap (`argocd-rbac-cm`)
* One mistake in the `api-server` Application sync policy
* One mistake in the `db-migrate` PostSync hook Job annotation

---

## 6. Your Task

Restore full GitOps compliance by identifying and fixing all three misconfigurations.

Requirements for the final state:

* `frontend-team` must be able to manage `frontend-app` via RBAC role binding to project `staging`
* `api-server` must automatically reconcile any config drift via `selfHeal: true`
* The `db-migrate` hook must delete itself when it **succeeds**, keeping the cluster
  clean so future syncs are never blocked

Constraints:

* Do not delete any existing Applications, RBAC roles, or hook Jobs
* Fix resources in place by editing the YAML files and reapplying with `kubectl apply`
* Do not change the RBAC role definitions — only fix the role binding

---

## 7. Success Criteria

1. **RBAC role binding — correct project**
   The `argocd-rbac-cm` ConfigMap must bind `john_doe` to
   `role:frontend-deployer` scoped to project `staging`.
   The broken binding references project `production` — a project
   `john_doe` has no Applications in, giving them no effective
   permissions whatsoever.

2. **api-server sync policy — selfHeal enabled**
   The `api-server` Application must have `syncPolicy.automated.selfHeal`
   set to `true`. With `selfHeal: false`, ArgoCD detects drift but takes
   no action — manual changes to the cluster persist indefinitely and
   silently override the Git source of truth.

3. **db-migrate hook — correct deletion policy**
   The `db-migrate` Job must carry the annotation:
   `argocd.argoproj.io/hook-delete-policy: HookSucceeded`
   The broken annotation uses `HookFailed` — this keeps the Job in the
   cluster when it fails (correct) but **also keeps it when it succeeds**
   — wait, `HookFailed` means delete only on failure. The correct value
   `HookSucceeded` deletes the Job after a successful run, preventing
   accumulation. With `BeforeHookCreation` as a safe alternative.

---

## 8. Background Knowledge

### 8.1 ArgoCD RBAC

ArgoCD RBAC is configured via the `argocd-rbac-cm` ConfigMap in the `argocd` namespace.

Policy format:
```
p, <subject>, <resource>, <action>, <project>/<object>, allow
g, <user-or-group>, <role>
```

Role binding (group → role) format:
```
g, frontend-team, role:frontend-deployer
```

The role itself defines which projects it can act on. If the role policy references
`proj:staging/*` but the group is accidentally bound to a role that targets
`proj:production/*`, the team cannot manage any staging resources.

Common mistake: copying a binding from one team and forgetting to update
the project name in the role policy.

---

### 8.2 ArgoCD Sync Policy — selfHeal

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true   # ← reconciles cluster drift back to Git
```

With `selfHeal: false`:
- ArgoCD will **detect** that the live cluster state differs from Git
- ArgoCD will **not** automatically apply the Git state to fix it
- The application shows `OutOfSync` but never transitions to `Synced`
- Manual intervention or a manual sync trigger is required every time

This directly violates the GitOps principle that Git is the single source of truth.

---

### 8.3 ArgoCD Resource Hooks

Resource hooks are Kubernetes Jobs annotated to run at specific sync phases:

```yaml
annotations:
  argocd.argoproj.io/hook: PostSync
  argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

Hook deletion policies:

```
| Policy            | Behaviour                                         |
| ----------------- | ------------------------------------------------- |
| HookSucceeded     | Delete the Job after it completes successfully    |
| HookFailed        | Delete the Job after it fails                     |
| BeforeHookCreation| Delete any existing Job before creating a new one |
```

If `HookFailed` is used on a migration Job:
- Successful runs → Job is **not** deleted (accumulates in cluster)
- Failed runs → Job is deleted
- After several deployments: many completed Jobs pile up
- ArgoCD hits resource comparison limits → `ComparisonError: too many resources`
- All future syncs for that Application are blocked

The correct policy for a migration job is `HookSucceeded` — clean up after
success, leave failed Jobs in place for debugging.

---

### 8.4 Debugging Commands

```bash
# Inspect RBAC ConfigMap
kubectl get configmap argocd-rbac-cm -n argocd -o yaml

# Inspect an Application's sync policy
kubectl get application api-server -n argocd -o yaml

# Inspect hook Job annotations
kubectl get job db-migrate -n backend -o yaml

# List all Jobs in a namespace (check for hook accumulation)
kubectl get jobs -n backend

# Check ArgoCD application sync status
kubectl get applications -n argocd
```