#!/bin/bash
# setup-deploy-lab.sh
# Run as: sudo bash setup-deploy-lab.sh

set -euo pipefail

function log() { echo "[setup] $*"; }

BASE_DIR="/home/user/deploydata"
REPORT_DIR="/home/user/deployreports"
SCRIPT_PATH="/home/user/deploy_report.py"
CSV_PATH="${BASE_DIR}/deployments.csv"

# --------------------------------------------------
# Directories
# --------------------------------------------------
log "Creating directories..."
mkdir -p "${BASE_DIR}"
mkdir -p "${REPORT_DIR}"

# --------------------------------------------------
# Input CSV
# --------------------------------------------------
log "Writing ${CSV_PATH}..."
cat > "${CSV_PATH}" << 'EOF'
env,status,start_time,end_time
prod,success,08:00:00,08:04:30
prod,success,09:15:00,09:21:45
prod,failed,10:30:00,10:33:10
staging,success,08:05:00,08:07:20
staging,failed,09:00:00,09:02:50
staging,success,11:00:00,11:03:00
dev,success,07:30:00,07:31:10
dev,success,08:45:00,08:46:50
dev,failed,10:00:00,10:02:30
dev,success,13:00:00,13:01:20
EOF

# --------------------------------------------------
# Half-baked Python pipeline
# compute_duration and group_by_env are left as stubs
# --------------------------------------------------
log "Writing ${SCRIPT_PATH}..."
cat > "${SCRIPT_PATH}" << 'PYEOF'
#!/usr/bin/env python3
"""
PipelineX Deployment Report
============================
Reads a CSV of deployment events, enriches each row with a computed
duration, groups results by environment, and writes a summary report.

Two functions are not yet implemented. Complete them to make the pipeline work.
"""

import os
import csv

CSV_FILE   = "/home/user/deploydata/deployments.csv"
REPORT_FILE = "/home/user/deployreports/summary.txt"


# ------------------------------------------------------------
# TODO 1 -- implement this function
# ------------------------------------------------------------
def compute_duration(start, end):
    """
    Given two time strings in HH:MM:SS format, return the number
    of seconds between them as an integer.

    Example:
        compute_duration("08:00:00", "08:04:30") -> 270

    Do not import any new modules.
    Hint: split each string on ":", convert each part to int,
    then compute total seconds for each time and subtract.
    """
    pass  # replace this


# ------------------------------------------------------------
# TODO 2 -- implement this function
# ------------------------------------------------------------
def group_by_env(enriched_rows):
    """
    Group a list of enriched deployment dicts by environment.

    Each dict in enriched_rows has these keys:
        env              -- e.g. "prod"
        status           -- "success" or "failed"
        duration_seconds -- integer

    Return a dict keyed by environment name. Each value is a dict with:
        total                -- total deployments in that env
        success              -- count of successful deployments
        failed               -- count of failed deployments
        avg_duration_seconds -- average duration, rounded to nearest int

    Do not import any new modules.
    Hint: build the result dict incrementally, then compute the average
    at the end using the built-in round() function.
    """
    pass  # replace this


# ------------------------------------------------------------
# Already implemented -- do not modify below this line
# ------------------------------------------------------------

def read_csv(filepath):
    """Read the deployments CSV and return a list of row dicts."""
    rows = []
    with open(filepath, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)
    return rows


def enrich(rows):
    """
    Add a duration_seconds key to each row by calling compute_duration.
    Returns a new list of enriched dicts with keys:
        env, status, duration_seconds
    """
    enriched = []
    for row in rows:
        duration = compute_duration(row["start_time"], row["end_time"])
        enriched.append({
            "env":              row["env"],
            "status":           row["status"],
            "duration_seconds": duration,
        })
    return enriched


def write_report(grouped):
    """Write the final summary report from the grouped dict."""
    os.makedirs(os.path.dirname(REPORT_FILE), exist_ok=True)

    total_deployments = sum(g["total"]  for g in grouped.values())
    total_failed      = sum(g["failed"] for g in grouped.values())

    with open(REPORT_FILE, "w") as f:
        f.write("PipelineX Deployment Summary\n")
        f.write("=" * 45 + "\n\n")
        for env in sorted(grouped.keys()):
            g = grouped[env]
            f.write(
                f"  {env:<10}  total={g['total']}  "
                f"success={g['success']}  failed={g['failed']}  "
                f"avg_duration_seconds={g['avg_duration_seconds']}\n"
            )
        f.write("\n" + "-" * 45 + "\n")
        f.write(f"  total_deployments={total_deployments}  total_failed={total_failed}\n")

    print(f"Report written to {REPORT_FILE}")
    print(f"Totals: deployments={total_deployments}  failed={total_failed}")


def run_pipeline():
    rows     = read_csv(CSV_FILE)
    enriched = enrich(rows)
    grouped  = group_by_env(enriched)
    write_report(grouped)


if __name__ == "__main__":
    run_pipeline()
PYEOF

chmod +x "${SCRIPT_PATH}"

# --------------------------------------------------
# Ownership
# --------------------------------------------------
chown -R user:user "${BASE_DIR}"
chown -R user:user "${REPORT_DIR}"
chown user:user "${SCRIPT_PATH}"

# --------------------------------------------------
# Info file
# --------------------------------------------------
log "Writing /home/user/imp_info.txt..."
cat > /home/user/imp_info.txt << EOF

============================================================
  PIPELINEX -- PYTHON DEPLOYMENT REPORT LAB
============================================================

  Script to edit:
    /home/user/deploy_report.py

  Input CSV:
    ${CSV_PATH}

  Run the pipeline:
    python3 /home/user/deploy_report.py

  Expected output file:
    /home/user/deployreports/summary.txt

  Expected results:
    prod      total=3  success=2  failed=1  avg_duration_seconds=288
    staging   total=3  success=2  failed=1  avg_duration_seconds=163
    dev       total=4  success=3  failed=1  avg_duration_seconds=102

    total_deployments=10  total_failed=3

============================================================
EOF
chown user:user /home/user/imp_info.txt

log "Setup complete."
echo ""
echo "============================================================"
echo "  PIPELINEX PYTHON LAB READY"
echo "============================================================"