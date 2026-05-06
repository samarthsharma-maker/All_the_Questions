#!/bin/bash
# setup-bash-lab.sh
# Run as: sudo bash setup-bash-lab.sh

set -euo pipefail

function log() { echo "[setup] $*"; }

BASE_DIR="/home/user/logharvest"

# --------------------------------------------------
# Directory structure
# --------------------------------------------------
log "Creating directory structure under /home/user/logharvest..."
mkdir -p "${BASE_DIR}/logs/app"
mkdir -p "${BASE_DIR}/logs/db"
mkdir -p "${BASE_DIR}/logs/worker"
mkdir -p "${BASE_DIR}/reports"
mkdir -p "${BASE_DIR}/script-logs"

# --------------------------------------------------
# Sample log files
# --------------------------------------------------
log "Writing sample log files..."

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

# No trailing newline on last line -- intentional, triggers bug 4
log "Writing sample CSV report..."
printf 'service,date,error_count,warn_count\napp,2024-03-01,3,1\ndb,2024-03-01,2,0\nworker,2024-03-01,2,1' \
    > "${BASE_DIR}/reports/daily.csv"

# --------------------------------------------------
# log-harvest
#
# BUG 1: pipe into while loop -- subshell variable scope
#   grep ... | while IFS= read -r line; do dir_errors=$((dir_errors+1)); done
#   The right-hand side of a pipe runs in a subshell. Variable changes
#   inside the loop are invisible to the parent shell -- dir_errors and
#   total_errors remain 0 after every loop iteration.
#   Fix: while IFS= read -r line; do ... done < <(grep -rh 'ERROR' "$dir")
#
# BUG 2: redirect order -- 2>&1 >file instead of >file 2>&1
#   exec 2>&1 >"$SCRIPT_LOG"
#   Bash processes redirections left to right. When 2>&1 is evaluated,
#   fd1 still points to the terminal so fd2 is also bound to the terminal.
#   Then >file redirects fd1 to the log file. Result: stdout is logged
#   but stderr escapes to the terminal and is never captured.
#   Fix: exec >"$SCRIPT_LOG" 2>&1
# --------------------------------------------------
log "Writing /home/user/log-harvest (bugs 1 and 2)..."
cat > /home/user/log-harvest << EOF
#!/bin/bash
set -euo pipefail

LOG_DIRS=("${BASE_DIR}/logs/app" "${BASE_DIR}/logs/db" "${BASE_DIR}/logs/worker")
REPORT_DIR="${BASE_DIR}/reports"
SCRIPT_LOG="${BASE_DIR}/script-logs/harvest.log"
DATE=\$(date '+%Y-%m-%d')
REPORT_FILE="\${REPORT_DIR}/harvest_\${DATE}.txt"

# BUG 2: redirect order is wrong -- stderr escapes to the terminal
# Fix: exec >"\$SCRIPT_LOG" 2>&1
exec 2>&1 >"\$SCRIPT_LOG"

echo "[\${DATE}] log-harvest starting"

total_errors=0

for dir in "\${LOG_DIRS[@]}"; do
    if [[ ! -d "\$dir" ]]; then
        echo "WARNING: directory not found: \$dir" >&2
        continue
    fi

    dir_errors=0

    # BUG 1: pipe into while -- \$dir_errors is always 0 after the loop
    # Fix: while IFS= read -r line; do ... done < <(grep -rh 'ERROR' "\$dir")
    grep -rh 'ERROR' "\$dir" | while IFS= read -r line; do
        dir_errors=\$((dir_errors + 1))
    done

    echo "  \$dir: \$dir_errors errors"
    total_errors=\$((total_errors + dir_errors))
done

echo "[\${DATE}] Total errors: \$total_errors"

cat > "\$REPORT_FILE" << REPORT
LogHarvest Daily Summary
Date: \${DATE}
Total Errors: \${total_errors}
Directories scanned: \${#LOG_DIRS[@]}
REPORT

echo "[\${DATE}] Report written to \$REPORT_FILE"
echo "[\${DATE}] log-harvest complete"
EOF
chmod +x /home/user/log-harvest

# --------------------------------------------------
# log-report
#
# BUG 3: unquoted array expansion -- ${arr[@]} not "${arr[@]}"
#   for dir in \${report_dirs[@]}; do
#   Without quotes, bash performs word splitting on each element.
#   A path containing a space is broken into separate tokens and
#   neither token resolves to a valid directory.
#   Fix: for dir in "\${report_dirs[@]}"; do
#
# BUG 4: read loop drops the last line when file has no trailing newline
#   while IFS=',' read -r service date errors warns; do
#   read returns non-zero at EOF even when it successfully populated
#   the variables from the final line. The while condition sees the
#   non-zero exit and skips processing that line entirely.
#   Fix: while IFS=',' read -r service date errors warns || [[ -n "\${service:-}" ]]; do
# --------------------------------------------------
log "Writing /home/user/log-report (bugs 3 and 4)..."
cat > /home/user/log-report << EOF
#!/bin/bash
set -euo pipefail

CSV_FILE="\${1:-${BASE_DIR}/reports/daily.csv}"

if [[ ! -f "\$CSV_FILE" ]]; then
    echo "ERROR: report file not found: \$CSV_FILE" >&2
    exit 1
fi

# Directories to scan for available reports
report_dirs=("${BASE_DIR}/reports" "${BASE_DIR}/reports/archive")

# BUG 3: missing quotes -- paths with spaces are word-split into separate tokens
# Fix: for dir in "\${report_dirs[@]}"; do
for dir in \${report_dirs[@]}; do
    if [[ -d "\$dir" ]]; then
        echo "Report directory available: \$dir"
    fi
done

echo ""
echo "LogHarvest Report Summary"
echo "========================="
echo "Source: \$CSV_FILE"
echo ""

total_errors=0
total_warns=0
line_count=0

# BUG 4: last line without trailing newline is silently dropped
# Fix: while IFS=',' read -r service date errors warns || [[ -n "\${service:-}" ]]; do
while IFS=',' read -r service date errors warns; do
    line_count=\$((line_count + 1))
    total_errors=\$((total_errors + errors))
    total_warns=\$((total_warns + warns))
    printf "  %-12s %s  errors=%-4s warns=%s\n" "\$service" "\$date" "\$errors" "\$warns"
done < <(tail -n +2 "\$CSV_FILE")

echo ""
echo "Totals: errors=\${total_errors}  warns=\${total_warns}  services=\${line_count}"
EOF
chmod +x /home/user/log-report

# --------------------------------------------------
# Ownership
# --------------------------------------------------
chown -R user:user "${BASE_DIR}"
chown user:user /home/user/log-harvest
chown user:user /home/user/log-report

# --------------------------------------------------
# imp_info.txt
# --------------------------------------------------
log "Writing /home/user/imp_info.txt..."
cat > /home/user/imp_info.txt << EOF

============================================================
  LOGHARVEST INC -- BASH SCRIPTING LAB
============================================================

  Scripts:
    /home/user/log-harvest
    /home/user/log-report

  Data directories:
    ${BASE_DIR}/logs/{app,db,worker}/
    ${BASE_DIR}/reports/daily.csv
    ${BASE_DIR}/script-logs/

  Run the scripts:
    bash /home/user/log-harvest
    bash /home/user/log-report ${BASE_DIR}/reports/daily.csv

  Expected log-harvest total: 7 errors (app=3, db=2, worker=2)
  Expected log-report lines:  3 services, errors=7, warns=2

============================================================
EOF
chown user:user /home/user/imp_info.txt

log "Setup complete."
echo ""
echo "============================================================"
echo "  LOGHARVEST BASH LAB READY -- 4 bugs planted"
echo "============================================================"