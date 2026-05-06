# FinEdge Payments: Broken Release Workflow

## 1. Company Background

* **Company:** FinEdge Payments
* **Industry:** Fintech / Payment Processing SaaS
* **Scale:** Growth-stage startup with approximately 110 engineers

Platform details:

* All backend services are released via a centralised GitHub Actions workflow
* The `service-release.yml` workflow is manually triggered by an engineer
  after each sprint to deploy a versioned release of a named service
* The workflow checks out the repository, runs the test suite, builds
  a release artifact, and publishes a release summary
* Releases must never ship if tests fail — a broken release reaching
  staging has previously caused payment processing outages
* All jobs run on GitHub-hosted runners (`ubuntu-latest`)

---

## 2. The Incident

A junior engineer was tasked with "tidying up" the release workflow during
a low-traffic maintenance window. They made four changes and committed
directly to the default branch without a review.

Key timeline:

* Changes pushed; pipeline showed no immediate syntax error from GitHub
* The next scheduled release was triggered — the **Run workflow** button
  had disappeared from the Actions tab entirely
* After the button was manually restored by reverting one change, the
  workflow was triggered but the job sat in a queue indefinitely, never
  starting
* After further investigation and fixes, a run finally started but failed
  immediately — the first step could not find any repository files
* When the team forced a run with a known-failing test, the workflow
  reported green — the failure had been silently swallowed

Business impact:

* Release delayed by 4 hours
* One broken build shipped to staging undetected — test failures masked
* Payment processing feature flag stuck at old version for two sprints
* Post-incident review identified four distinct misconfigurations

---

## 3. The Broken Workflow

The setup script has already written the broken workflow file to your lab machine at:

```
/home/user/finedge-actions-lab/.github/workflows/service-release.yml
```

Copy it into your GitHub repository, commit, and push it to the default branch:

```bash
# Inside your cloned GitHub repository
mkdir -p .github/workflows

cp /home/user/finedge-actions-lab/.github/workflows/service-release.yml \
   .github/workflows/service-release.yml

git add .github/workflows/service-release.yml
git commit -m "Add service-release workflow"
git push
```

Then open the file, find all four bugs, fix them, and push the corrected version.

---

## 4. Your Task

There are **four bugs** in the workflow above. Find them, fix them, push
the corrected file, and trigger a successful workflow run.

Requirements for the final state:

* The workflow must be triggerable via the **Run workflow** button in the
  GitHub Actions UI
* The `release` job must run on `ubuntu-latest`
* Repository files must be available to all steps that need them
* A failing test step must **not** be silently ignored — it must fail the
  entire job

---

## 5. Success Criteria

1. **Trigger event name is spelled correctly**
   `workflow_dipatch` is not a recognised GitHub Actions event. GitHub
   silently ignores unknown event keys — the workflow is parsed without
   error but the **Run workflow** button never appears in the Actions UI.
   Fix: rename to `workflow_dispatch`.

2. **Job runs on `ubuntu-latest`, not a self-hosted label**
   `self-hosted-prod` is not a registered runner in this repository.
   Any job targeting an unavailable runner label sits in the queue
   indefinitely — it will never be picked up and the run will eventually
   time out. Fix: change `runs-on` to `ubuntu-latest`.

3. **`actions/checkout` is the first step**
   The `checkout` step appears after `Print release info` and `Run tests`,
   meaning those earlier steps execute against a bare runner with no
   repository files present. Any step that reads from the repo — scripts,
   config files, lockfiles — will fail with "file not found". Fix: move
   `actions/checkout@v3` to be the first step in the job.

4. **`continue-on-error: true` removed from the test step**
   `continue-on-error: true` causes GitHub Actions to mark a step as
   passed even when its exit code is non-zero. A failing test suite
   produces a green checkmark — the job proceeds to build and publish
   a broken release artifact with no indication that tests failed.
   Fix: remove `continue-on-error: true` from the `Run tests` step.

---

## 6. Background Knowledge

### 6.1 GitHub Actions Event Names Are Silently Ignored When Misspelled

GitHub does not validate event key names in workflow files. A workflow
with `on: workflow_dipatch` is syntactically valid YAML and will be
accepted by GitHub. The workflow appears in the repository but the
**Run workflow** button is absent because no recognised trigger matches.
This is one of the most common and hardest-to-spot GitHub Actions mistakes.

### 6.2 Self-Hosted Runners Must Be Registered

`runs-on` accepts either a GitHub-hosted runner label (`ubuntu-latest`,
`windows-latest`, `macos-latest`) or a label matching a registered
self-hosted runner. If the label does not match any available runner,
the job enters a permanent queue. GitHub does not surface this as an
error — the run simply shows as "Queued" indefinitely.

### 6.3 actions/checkout Must Come First

A GitHub Actions runner starts each job with an empty workspace. No
repository files are present until `actions/checkout` runs. Any step
that references files from the repository — shell scripts, test configs,
Makefiles — must be placed **after** the checkout step. Placing checkout
later in the job means early steps operate on an empty directory.


### 6.5 Debugging Commands

```bash
# Decode and inspect a workflow file via the API
ACCESS_TOKEN="<your-pat>"
USERNAME="<your-username>"
REPO="<your-repo>"

curl -s \
  -H "Authorization: token $ACCESS_TOKEN" \
  https://api.github.com/repos/$USERNAME/$REPO/contents/.github/workflows/service-release.yml \
  | jq -r '.content' | base64 --decode

# Check recent workflow runs
curl -s \
  -H "Authorization: token $ACCESS_TOKEN" \
  "https://api.github.com/repos/$USERNAME/$REPO/actions/runs?per_page=5" \
  | jq '.workflow_runs[] | {id, event, conclusion, status}'
```

---

## 7. Configure GitHub Credentials

Create a GitHub Personal Access Token (PAT) with scopes:
**repo, workflow, admin:repo_hook**

Create `/home/user/github_creds.json` with exactly this structure:

```json
{
  "repository_name": "<your_repo_name>",
  "access_token": "<your_github_personal_access_token>",
  "username": "<your_github_username>"
}
```