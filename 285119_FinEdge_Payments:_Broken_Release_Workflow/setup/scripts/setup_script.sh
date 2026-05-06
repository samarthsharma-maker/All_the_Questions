#!/bin/bash
# setup-github-actions-debug-lab.sh
# Writes the broken FinEdge release workflow to the lab directory.
# Run as: bash setup-github-actions-debug-lab.sh
#
# After running this script:
#   1. Copy the workflow file into your GitHub repository at:
#      .github/workflows/service-release.yml
#   2. Commit and push to the default branch (main or master)
#   3. Find and fix the four bugs in the workflow
#   4. Trigger a successful run via the GitHub Actions UI

set -euo pipefail

HOME_DIR="/home/user"
BASE_DIR="/home/user/finedge-actions-lab"
WORKFLOW_DIR="${BASE_DIR}/.github/workflows"

mkdir -p "${WORKFLOW_DIR}"

function log() { echo "[setup] $*"; }

# --------------------------------------------------
# Write the broken workflow file
#
# Four bugs are intentionally planted:
#
# BUG 1 — Trigger event misspelled: 'workflow_dipatch'
#   GitHub silently ignores unknown event names. The workflow
#   is valid YAML and is accepted without error, but the
#   'Run workflow' button never appears in the Actions UI.
#   Correct: workflow_dispatch
#
# BUG 2 — runs-on targets a non-existent self-hosted runner: 'self-hosted-prod'
#   Jobs targeting an unregistered runner label queue indefinitely.
#   GitHub surfaces no error — the run simply shows as 'Queued' forever.
#   Correct: ubuntu-latest
#
# BUG 3 — actions/checkout is not the first step
#   The checkout step appears after 'Print release info' and 'Run tests'.
#   A runner starts each job with an empty workspace — any step that
#   reads repository files before checkout will fail with file not found.
#   Correct: move actions/checkout@v3 to be the first step.
#
# BUG 4 — continue-on-error: true on the test step
#   This causes GitHub Actions to mark the step as passed regardless of
#   exit code. A failing test suite produces a green checkmark and the
#   release proceeds — broken builds ship silently.
#   Correct: remove continue-on-error: true from the Run tests step.
# --------------------------------------------------
function write_broken_workflow() {
    log "Writing broken workflow file..."

    cat > "${WORKFLOW_DIR}/service-release.yml" <<'EOF'
name: Service Release

on:
  workflow_dipatch:
    inputs:
      service_name:
        description: "Name of the service to release"
        type: string
        required: true
      version:
        description: "Release version (e.g. v1.4.0)"
        type: string
        required: true

jobs:
  release:
    runs-on: self-hosted-prod
    steps:
      - name: Print release info
        run: |
          echo "Releasing ${{ inputs.service_name }} version ${{ inputs.version }}"

      - name: Run tests
        continue-on-error: true
        run: |
          echo "Running test suite..."
          # In a real workflow this would invoke the test runner
          # e.g.: ./scripts/run-tests.sh

      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Build release artifact
        run: |
          echo "Building artifact for ${{ inputs.service_name }}..."
          mkdir -p dist
          echo "${{ inputs.version }}" > dist/VERSION

      - name: Publish release summary
        run: |
          echo "Release ${{ inputs.version }} of ${{ inputs.service_name }} complete."
EOF

    log "  Written to: ${WORKFLOW_DIR}/service-release.yml"
}

# --------------------------------------------------
# Write important info file
# --------------------------------------------------
function create_imp_info_file() {
    cat > "${HOME_DIR}/imp_info.txt" <<EOF

============================================================
  FINEDGE PAYMENTS — GITHUB ACTIONS DEBUG LAB
============================================================

  Broken workflow written to:
    ${WORKFLOW_DIR}/service-release.yml

  ── NEXT STEPS ──────────────────────────────────────────

  1. Create your credentials file at /home/user/github_creds.json:

       {
         "repository_name": "<your_repo_name>",
         "access_token":    "<your_github_pat>",
         "username":        "<your_github_username>"
       }

     PAT scopes required: repo, workflow, admin:repo_hook

  2. Copy the workflow into your GitHub repository:

       In your cloned repo, create the directory and copy the file:

         mkdir -p .github/workflows
         cp ${WORKFLOW_DIR}/service-release.yml \\
            <your-repo>/.github/workflows/service-release.yml

  3. Commit and push to your default branch (main or master):

         cd <your-repo>
         git add .github/workflows/service-release.yml
         git commit -m "Add service-release workflow"
         git push

  4. Find and fix the four bugs in the workflow file.
     Then trigger a successful run from the GitHub Actions UI:

         Repository → Actions → Service Release → Run workflow

  ── HINTS ───────────────────────────────────────────────

  There are 4 bugs. Each affects a different part of the workflow:
    - One prevents the workflow from appearing in the Actions UI at all
    - One prevents the job from ever starting
    - One causes steps to run against an empty workspace
    - One silently hides test failures

  Start by reading the workflow YAML carefully, then cross-reference
  with the GitHub Actions documentation for each concept.

============================================================
EOF
    log "  imp_info.txt written to ${HOME_DIR}"
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "Setting up FinEdge Actions Debug Lab..."
    echo ""

    echo "[1/2] Writing broken workflow file..."
    write_broken_workflow

    echo "[2/2] Writing important info file..."
    create_imp_info_file

    echo ""
    echo "============================================================"
    echo "  FINEDGE PAYMENTS — GITHUB ACTIONS DEBUG LAB READY"
    echo "============================================================"
    echo ""
    echo "  Broken workflow: ${WORKFLOW_DIR}/service-release.yml"
    echo ""
    echo "  Next: copy the file into your GitHub repo, push it,"
    echo "        find all four bugs, fix them, and trigger a"
    echo "        successful workflow run."
    echo ""
    echo "  Run: cat ${HOME_DIR}/imp_info.txt  for full instructions"
    echo "============================================================"
}

main

chown -R user:user "${BASE_DIR}" 2>/dev/null || true