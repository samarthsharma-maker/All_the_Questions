# What Needs to Be Fixed

This file documents all the issues that need to be identified and fixed across the RBAC, Network Policy, and Resource Quota layers.

---

## Layer 1: RBAC Configuration Issues

### Issue 1.1: ServiceAccount Location
- **Current State**: A ServiceAccount named `ci-runner` exists in the `default` namespace
- **Problem**: The CI pipeline needs to run in the `dev` and `staging` namespaces, not default
- **Investigation Steps**:
  ```bash
  kubectl get serviceaccounts -n default
  kubectl get serviceaccounts -n dev
  kubectl get serviceaccounts -n staging
  ```
- **Fix Required**: Move the ServiceAccount to the correct namespaces

---

### Issue 1.2: Role Permissions in dev namespace
- **Current State**: A Role named `ci-reader` exists in the `dev` namespace
- **Problem**: The verbs configured are wrong for the CI pipeline's needs
- **Investigation Steps**:
  ```bash
  kubectl get role ci-reader -n dev -o yaml
  kubectl get role ci-reader -n dev -o jsonpath='{.rules[*].verbs[*]}'
  kubectl get role ci-reader -n dev -o jsonpath='{.rules[*].resources[*]}'
  ```
- **What You'll Find**:
  - Current verbs: `create`, `delete`, `update`
  - Current resources: `pods` only
- **Fix Required**: Update the Role with the correct verbs and resources needed for read-only access

---

### Issue 1.3: Role Permissions in staging namespace
- **Current State**: A Role named `ci-reader` exists in the `staging` namespace
- **Problem**: Same as Issue 1.2 - wrong permissions configured
- **Investigation Steps**:
  ```bash
  kubectl get role ci-reader -n staging -o yaml
  ```
- **Fix Required**: Update the Role with the same correct permissions as the dev namespace

---

### Issue 1.4: RoleBinding Subject Name in dev namespace
- **Current State**: A RoleBinding named `ci-runner-binding` exists in the `dev` namespace
- **Problem**: The subject referenced doesn't match the actual ServiceAccount name
- **Investigation Steps**:
  ```bash
  kubectl get rolebinding ci-runner-binding -n dev -o yaml
  kubectl get rolebinding ci-runner-binding -n dev -o jsonpath='{.subjects[0].name}'
  ```
- **What You'll Find**: Subject name is `ci-runners` (plural)
- **Fix Required**: Correct the subject name to match the actual ServiceAccount

---

### Issue 1.5: RoleBinding Subject Name in staging namespace
- **Current State**: A RoleBinding named `ci-runner-binding` exists in the `staging` namespace
- **Problem**: Same as Issue 1.4 - subject name mismatch
- **Investigation Steps**:
  ```bash
  kubectl get rolebinding ci-runner-binding -n staging -o yaml
  ```
- **Fix Required**: Correct the subject name to match the actual ServiceAccount

---

## Layer 2: Resource Quota Issues

### Issue 2.1: Overly Restrictive ResourceQuota in dev namespace
- **Current State**: A ResourceQuota named `pipeline-quota` exists in the `dev` namespace
- **Problem**: Limits are too tight for CI pipeline operations
- **Investigation Steps**:
  ```bash
  kubectl get resourcequota -n dev
  kubectl get resourcequota pipeline-quota -n dev -o yaml
  kubectl describe resourcequota pipeline-quota -n dev
  ```
- **What You'll Find**:
  - Pod limit: 1 (pipeline needs more for verification)
  - Memory limit: 64Mi (too small)
  - CPU limit: 0.1 (too small)
- **Recommended Limits**:
  - Pod limit: 10-20 pods
  - Memory limit: 512Mi to 1Gi
  - CPU limit: 0.5 to 2 cores
- **Fix Required**: Increase limits to reasonable values for CI pipeline verification

---

### Issue 2.2: Overly Restrictive ResourceQuota in staging namespace
- **Current State**: A ResourceQuota named `pipeline-quota` exists in the `staging` namespace
- **Problem**: Same as Issue 3.1 - limits prevent deployment verification
- **Investigation Steps**:
  ```bash
  kubectl get resourcequota -n staging
  kubectl describe resourcequota pipeline-quota -n staging
  ```
- **Recommended Limits**:
  - Pod limit: 10-20 pods
  - Memory limit: 512Mi to 1Gi
  - CPU limit: 0.5 to 2 cores
- **Fix Required**: Increase limits to reasonable values

---

## Verification Commands

Once you believe you've fixed the issues, use these commands to verify:

### RBAC Verification
```bash
# Test permissions in dev namespace
kubectl auth can-i get pods --as=system:serviceaccount:dev:ci-runner -n dev
kubectl auth can-i get pods/log --as=system:serviceaccount:dev:ci-runner -n dev
kubectl auth can-i delete pods --as=system:serviceaccount:dev:ci-runner -n dev

# Test permissions in staging namespace
kubectl auth can-i get pods --as=system:serviceaccount:staging:ci-runner -n staging
kubectl auth can-i get pods/log --as=system:serviceaccount:staging:ci-runner -n staging
kubectl auth can-i delete pods --as=system:serviceaccount:staging:ci-runner -n staging
```

### Resource Quota Verification
```bash
# Check quotas are reasonable
kubectl get resourcequota -n dev
kubectl describe resourcequota pipeline-quota -n dev
kubectl get resourcequota -n staging
kubectl describe resourcequota pipeline-quota -n staging
```

---

## Summary of Required Fixes

| Issue | Component | Fix Type |
|-------|-----------|----------|
| 1.1 | ServiceAccount | Move from default → dev & staging |
| 1.2 | Role (dev) | Update verbs & add `pods/log` resource |
| 1.3 | Role (staging) | Update verbs & add `pods/log` resource |
| 1.4 | RoleBinding (dev) | Fix subject name |
| 1.5 | RoleBinding (staging) | Fix subject name |
| 2.1 | ResourceQuota (dev) | Increase limits |
| 2.2 | ResourceQuota (staging) | Increase limits |

**Total Issues to Fix: 7**
