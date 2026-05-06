#!/bin/bash
# setup-databridge-lab.sh
# Deploys the broken DataBridge pipeline components.
# Run as: sudo bash setup-databridge-lab.sh

set -euo pipefail

function log() { echo "[setup] $*"; }

# --------------------------------------------------
# Directories
# --------------------------------------------------
log "Creating directories..."
mkdir -p /etc/databridge
mkdir -p /var/log/databridge
mkdir -p /var/data/databridge/{input,processed,archive}
chown -R user:user /var/log/databridge
chown -R user:user /var/data/databridge

# --------------------------------------------------
# Config file — the CORRECT file that should be loaded
# EnvironmentFile in the unit points to the WRONG path (bug 1)
# --------------------------------------------------
log "Writing /etc/databridge/databridge.conf..."
cat > /etc/databridge/databridge.conf << 'EOF'
BATCH_SIZE=500
BATCH_FLAGS="--mode=batch --workers=4 --timeout=120"
DB_HOST=localhost
DB_PORT=5432
LOG_LEVEL=info
THRESHOLD=100
EOF

# Also write the wrong file the unit actually points to (empty — so vars are undefined)
# BUG 1: unit has EnvironmentFile=/etc/databridge/databridge.cnf
#        correct path is /etc/databridge/databridge.conf
log "Writing /etc/databridge/databridge.cnf (wrong file, intentionally empty)..."
cat > /etc/databridge/databridge.cnf << 'EOF'
# This file is intentionally empty.
# The correct config is at /etc/databridge/databridge.conf
EOF

# --------------------------------------------------
# systemd unit
#
# BUG 1: EnvironmentFile=/etc/databridge/databridge.cnf
#        Correct: EnvironmentFile=/etc/databridge/databridge.conf
#        Effect: all env vars (BATCH_FLAGS, BATCH_SIZE, DB_HOST, etc.)
#        are undefined at runtime — daemon runs with empty config.
# --------------------------------------------------
log "Writing /etc/systemd/system/databridge.service (bug 1: wrong EnvironmentFile)..."
cat > /etc/systemd/system/databridge.service << 'EOF'
[Unit]
Description=DataBridge Analytics Processing Daemon
After=network.target
Documentation=https://internal.databridge.io/ops/daemon

[Service]
Type=simple
User=user
EnvironmentFile=/etc/databridge/databridge.cnf
ExecStart=/usr/local/bin/databridge-process $BATCH_FLAGS
ExecStop=/bin/kill -TERM $MAINPID
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=databridge

[Install]
WantedBy=multi-user.target
EOF

# --------------------------------------------------
# Processing script
#
# BUG 2: Integer comparison uses > instead of -gt
#   [ "$batch_count" > "$THRESHOLD" ]
#   In bash single-bracket [ ], > is a string redirect operator,
#   NOT a numeric comparison. This creates a file named after the
#   value of $THRESHOLD in the current directory, and the test
#   always exits 0 (true) regardless of the actual count.
#   Correct: [ "$batch_count" -gt "$THRESHOLD" ]
#
# BUG 2b: set -e without set -o pipefail
#   pipeline failures (middle of pipe) are silently ignored
#   Correct: set -euo pipefail
# --------------------------------------------------
log "Writing /usr/local/bin/databridge-process (bug 2: bad comparison + no pipefail)..."
cat > /usr/local/bin/databridge-process << 'EOF'
#!/bin/bash
set -e

LOG=/var/log/databridge/process.log
INPUT_DIR=/var/data/databridge/input
PROCESSED_DIR=/var/data/databridge/processed

exec >> "$LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] databridge-process started. BATCH_FLAGS=${BATCH_FLAGS:-<unset>} THRESHOLD=${THRESHOLD:-<unset>}"

# Count files waiting to process
batch_count=$(find "$INPUT_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Batch count: $batch_count"

# BUG 2: > is a redirect in [ ], not a numeric comparator.
# This silently creates a file named by the value of $THRESHOLD
# and always evaluates as true (exit 0).
# Fix: use -gt for integer comparison
if [ "$batch_count" > "$THRESHOLD" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: batch count $batch_count exceeds threshold $THRESHOLD"
fi

# Move processed files
find "$INPUT_DIR" -maxdepth 1 -type f | while read -r f; do
    # BUG 2b: this pipeline — if 'find' fails partway, the while loop
    # exits 0 because bash only checks the last command's exit code
    # without pipefail. Silent data loss possible.
    mv "$f" "$PROCESSED_DIR/"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processed: $(basename "$f")"
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] databridge-process cycle complete."

# Keep daemon alive
sleep infinity
EOF
chmod +x /usr/local/bin/databridge-process

# --------------------------------------------------
# Cleanup script (called by cron — correct script, broken cron entry)
# --------------------------------------------------
log "Writing /usr/local/bin/databridge-cleanup..."
cat > /usr/local/bin/databridge-cleanup << 'EOF'
#!/bin/bash
set -euo pipefail

PROCESSED_DIR=/var/data/databridge/processed
ARCHIVE_DIR=/var/data/databridge/archive
LOG=/var/log/databridge/cleanup.log
RETENTION_DAYS=7

exec >> "$LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting cleanup. Retention: ${RETENTION_DAYS} days."

# Archive files older than retention period
find "$PROCESSED_DIR" -maxdepth 1 -type f -mtime +"$RETENTION_DAYS" | while read -r f; do
    mv "$f" "$ARCHIVE_DIR/"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Archived: $(basename "$f")"
done

# Remove archives older than 30 days
find "$ARCHIVE_DIR" -maxdepth 1 -type f -mtime +30 -delete

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleanup complete."
EOF
chmod +x /usr/local/bin/databridge-cleanup

# --------------------------------------------------
# Cron job
#
# BUG 3: No PATH set in cron environment.
# Cron's default PATH is /usr/bin:/bin — /usr/local/bin is absent.
# The cron entry calls 'databridge-cleanup' by name (not full path),
# so cron cannot find the script and silently fails.
# No MAILTO means the error output is swallowed completely.
# Fix: add PATH=/usr/local/bin:/usr/bin:/bin at the top of the file,
#      OR change the command to /usr/local/bin/databridge-cleanup
# --------------------------------------------------
log "Writing /etc/cron.d/databridge-cleanup (bug 3: no PATH, bare script name)..."
cat > /etc/cron.d/databridge-cleanup << 'EOF'
# DataBridge nightly cleanup
# Runs at 02:00 every day as user
0 2 * * * user databridge-cleanup
EOF
chmod 644 /etc/cron.d/databridge-cleanup

# --------------------------------------------------
# Health-check script
#
# BUG 4: Uses kill -9 $pid to "restart" the daemon.
# SIGKILL (signal 9) cannot be caught or ignored — it terminates
# the process immediately with no cleanup. Critically, it bypasses
# systemd entirely: the unit's ExecStop is never called, systemd
# does not observe a clean exit, and the unit transitions to
# 'failed' state. The Restart=on-failure policy then attempts a
# restart but the unit is in failed state, which may block it
# depending on StartLimitBurst configuration.
# Fix: use 'systemctl restart databridge' — lets systemd manage
#      the full lifecycle cleanly.
# --------------------------------------------------
log "Writing /usr/local/bin/databridge-healthcheck (bug 4: kill -9 instead of systemctl restart)..."
cat > /usr/local/bin/databridge-healthcheck << 'EOF'
#!/bin/bash
set -euo pipefail

SERVICE=databridge
LOG=/var/log/databridge/healthcheck.log
PIDFILE=/var/run/databridge.pid

exec >> "$LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running health check for $SERVICE..."

# Check if the service is active
if ! systemctl is-active --quiet "$SERVICE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Service $SERVICE is not active. Attempting recovery..."

    # BUG 4: kill -9 bypasses systemd — the unit enters failed state
    # and does not recover cleanly. Use systemctl restart instead.
    pid=$(systemctl show -p MainPID --value "$SERVICE" 2>/dev/null || echo "")
    if [ -n "$pid" ] && [ "$pid" != "0" ]; then
        kill -9 "$pid"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sent SIGKILL to PID $pid"
    fi

    sleep 2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Recovery attempted. Check service status manually."
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Service $SERVICE is healthy."
fi
EOF
chmod +x /usr/local/bin/databridge-healthcheck

# --------------------------------------------------
# Enable and start the service
# --------------------------------------------------
log "Enabling and starting databridge.service..."
systemctl daemon-reload
systemctl enable databridge 2>/dev/null || true
systemctl restart databridge 2>/dev/null || true

# --------------------------------------------------
# Seed some input files for realism
# --------------------------------------------------
log "Seeding input data files..."
for i in $(seq 1 5); do
    echo "record_id,value,timestamp" > /var/data/databridge/input/batch_$(date +%s%N)_${i}.csv
    echo "100${i},$(( RANDOM % 1000 )),$(date -Iseconds)" >> /var/data/databridge/input/batch_$(date +%s%N)_${i}.csv
done
chown -R user:user /var/data/databridge

# --------------------------------------------------
# imp_info.txt
# --------------------------------------------------
log "Writing /home/user/imp_info.txt..."
cat > /home/user/imp_info.txt << 'EOF'

============================================================
  DATABRIDGE ANALYTICS — PIPELINE TROUBLESHOOTING LAB
============================================================

  4 bugs are deployed across these files:
    /etc/systemd/system/databridge.service
    /usr/local/bin/databridge-process
    /etc/cron.d/databridge-cleanup
    /usr/local/bin/databridge-healthcheck

  Config reference:
    /etc/databridge/databridge.conf   ← the correct config file

  After editing the systemd unit:
    sudo systemctl daemon-reload
    sudo systemctl restart databridge

  Useful commands:
    systemctl status databridge
    journalctl -u databridge -n 50
    sudo systemctl daemon-reload && sudo systemctl restart databridge

============================================================
EOF
chown user:user /home/user/imp_info.txt

log "Setup complete."
echo ""
echo "============================================================"
echo "  DATABRIDGE LAB READY — 4 bugs planted"
echo "============================================================"