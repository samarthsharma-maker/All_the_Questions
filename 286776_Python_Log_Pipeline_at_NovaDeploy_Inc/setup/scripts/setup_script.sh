#!/bin/bash
# setup-python-lab.sh
# Run as: sudo bash setup-python-lab.sh

set -euo pipefail

function log() { echo "[setup] $*"; }

BASE_DIR="/home/user/novadev"
REPORT_DIR="/home/user/logreports"
SCRIPT_PATH="/home/user/log_pipeline.py"

# --------------------------------------------------
# Directories
# --------------------------------------------------
log "Creating directories..."
mkdir -p "${BASE_DIR}/logs/app"
mkdir -p "${BASE_DIR}/logs/db"
mkdir -p "${BASE_DIR}/logs/worker"
mkdir -p "${REPORT_DIR}"

# --------------------------------------------------
# Log files (same content as the bash lab)
# --------------------------------------------------
log "Writing log files..."

cat > "${BASE_DIR}/logs/app/app.log" << 'EOF'
2024-03-01 08:00:01 INFO  Starting application server
2024-03-01 08:00:02 INFO  Connected to database
2024-03-01 08:15:44 ERROR Failed to process request: timeout after 30s
2024-03-01 09:02:11 INFO  Scheduled job completed
2024-03-01 09:45:03 ERROR Null pointer exception in PaymentService.process()
2024-03-01 10:12:55 WARN  Memory usage above 80%
2024-03-01 11:33:21 ERROR Connection pool exhausted
2024-03-01 12:00:00 INFO  Health check passed
EOF

cat > "${BASE_DIR}/logs/db/db.log" << 'EOF'
2024-03-01 08:00:05 INFO  PostgreSQL 15.2 started
2024-03-01 08:30:17 ERROR Deadlock detected on table orders
2024-03-01 09:11:09 INFO  Checkpoint complete
2024-03-01 10:45:33 ERROR Replication lag exceeded threshold: 120s
2024-03-01 11:00:00 INFO  Autovacuum completed on table sessions
EOF

cat > "${BASE_DIR}/logs/worker/worker.log" << 'EOF'
2024-03-01 08:01:00 INFO  Worker pool initialized with 8 workers
2024-03-01 08:45:12 ERROR Failed to dequeue job: redis connection refused
2024-03-01 09:30:44 INFO  Processed 1420 jobs
2024-03-01 10:15:06 ERROR Job retry limit exceeded for job_id=9924
2024-03-01 11:55:59 WARN  Queue depth above warning threshold
EOF

# --------------------------------------------------
# Half-baked Python pipeline
# parse_log_line and summarize are left as stubs
# --------------------------------------------------
log "Writing /home/user/log_pipeline.py..."
cat > "${SCRIPT_PATH}" << 'PYEOF'
#!/usr/bin/env python3
"""
NovaDeploy Log Pipeline
=======================
Reads log files for each service, parses every line, builds a summary,
and writes a report to /home/user/logreports/summary.txt.

Two functions are not yet implemented. Complete them to make the pipeline work.
"""

import os

BASE_DIR = "/home/user/novadev/logs"
REPORT_FILE = "/home/user/logreports/summary.txt"

SERVICES = {
    "app":    os.path.join(BASE_DIR, "app", "app.log"),
    "db":     os.path.join(BASE_DIR, "db", "db.log"),
    "worker": os.path.join(BASE_DIR, "worker", "worker.log"),
}


# ------------------------------------------------------------
# TODO 1 -- implement this function
# ------------------------------------------------------------
def parse_log_line(line):
    """
    Parse a single log line into a dictionary.

    Each log line follows this format:
        2024-03-01 08:15:44 ERROR Failed to process request: timeout after 30s

    Return a dict with keys: date, time, level, message.
    Return None if the line has fewer than 4 whitespace-separated parts.

    Hint: use str.split() with maxsplit=3 so that the message field
    keeps its internal spaces intact.
    """
    pass  # replace this


# ------------------------------------------------------------
# TODO 2 -- implement this function
# ------------------------------------------------------------
def summarize(parsed_lines, service_name):
    """
    Build a summary dictionary for one service.

    parsed_lines -- list of dicts returned by parse_log_line (None entries
                    have already been filtered out before this is called)
    service_name -- string name of the service, e.g. "app"

    Return a dict with keys:
        service  -- the service_name string
        errors   -- count of lines where level == "ERROR"
        warnings -- count of lines where level == "WARN"
    """
    pass  # replace this


# ------------------------------------------------------------
# Already implemented -- do not modify below this line
# ------------------------------------------------------------

def read_lines(filepath):
    """Read all lines from a file and return them as a list of strings."""
    with open(filepath, "r") as f:
        return f.readlines()


def parse_all(lines):
    """
    Apply parse_log_line to every line and filter out None results.
    Returns a list of parsed dicts.
    """
    parsed = [parse_log_line(line.strip()) for line in lines]
    return [p for p in parsed if p is not None]


def write_report(summaries):
    """Write the final report file from a list of summary dicts."""
    os.makedirs(os.path.dirname(REPORT_FILE), exist_ok=True)
    total_errors = sum(s["errors"] for s in summaries)
    total_warns  = sum(s["warnings"] for s in summaries)

    with open(REPORT_FILE, "w") as f:
        f.write("NovaDeploy Daily Log Summary\n")
        f.write("=" * 40 + "\n\n")
        for s in summaries:
            f.write(
                f"  {s['service']:<10}  errors={s['errors']}  warnings={s['warnings']}\n"
            )
        f.write("\n" + "-" * 40 + "\n")
        f.write(f"  TOTAL       errors={total_errors}  warnings={total_warns}\n")

    print(f"Report written to {REPORT_FILE}")
    print(f"Total: errors={total_errors}  warnings={total_warns}  services={len(summaries)}")


def run_pipeline():
    summaries = []
    for service_name, filepath in SERVICES.items():
        lines   = read_lines(filepath)
        parsed  = parse_all(lines)
        summary = summarize(parsed, service_name)
        summaries.append(summary)
    write_report(summaries)


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
  NOVADEPLOY INC -- PYTHON LOG PIPELINE LAB
============================================================

  Script to edit:
    /home/user/log_pipeline.py

  Log files:
    ${BASE_DIR}/logs/app/app.log
    ${BASE_DIR}/logs/db/db.log
    ${BASE_DIR}/logs/worker/worker.log

  Run the pipeline:
    python3 /home/user/log_pipeline.py

  Expected output file:
    /home/user/logreports/summary.txt

  Expected totals:
    app     errors=3  warnings=1
    db      errors=2  warnings=0
    worker  errors=2  warnings=1
    TOTAL   errors=7  warnings=2

============================================================
EOF
chown user:user /home/user/imp_info.txt

log "Setup complete."
echo ""
echo "============================================================"
echo "  NOVADEPLOY PYTHON LAB READY"
echo "============================================================"