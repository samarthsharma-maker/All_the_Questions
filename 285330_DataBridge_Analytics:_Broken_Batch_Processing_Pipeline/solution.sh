#!/bin/bash
# solution.sh — Applies all four fixes to the DataBridge pipeline lab.
# Run as: sudo bash solution.sh

set -euo pipefail

echo "============================================================"
echo "  DATABRIDGE ANALYTICS LAB — APPLYING FIXES"
echo "============================================================"
echo ""

# --------------------------------------------------
# FIX 1: systemd EnvironmentFile path
# Wrong:   EnvironmentFile=/etc/databridge/databridge.cnf
# Correct: EnvironmentFile=/etc/databridge/databridge.conf
# --------------------------------------------------
echo "[1/4] Fixing EnvironmentFile path in databridge.service..."

cat > /etc/systemd/system/databridge.service << 'EOF'
[Unit]
Description=DataBridge Analytics Processing Daemon
After=network.target
Documentation=https://internal.databridge.io/ops/daemon

[Service]
Type=simple
User=user
EnvironmentFile=/etc/databridge/databridge.conf
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

systemctl daemon-reload
systemctl restart databridge
echo "  Done. Service reloaded and restarted."
echo ""

# --------------------------------------------------
# FIX 2: Processing script
#   a) [ "$batch_count" > "$THRESHOLD" ]  →  [ "$batch_count" -gt "$THRESHOLD" ]
#   b) set -e  →  set -euo pipefail
# --------------------------------------------------
echo "[2/4] Fixing integer comparison and pipefail in databridge-process..."

cat > /usr/local/bin/databridge-process << 'EOF'
#!/bin/bash
set -euo pipefail

LOG=/var/log/databridge/process.log
INPUT_DIR=/var/data/databridge/input
PROCESSED_DIR=/var/data/databridge/processed

exec >> "$LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] databridge-process started. BATCH_FLAGS=${BATCH_FLAGS:-<unset>} THRESHOLD=${THRESHOLD:-<unset>}"

batch_count=$(find "$INPUT_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Batch count: $batch_count"

# Fix 2a: use -gt for integer comparison
if [ "$batch_count" -gt "${THRESHOLD:-100}" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: batch count $batch_count exceeds threshold ${THRESHOLD:-100}"
fi

find "$INPUT_DIR" -maxdepth 1 -type f | while read -r f; do
    mv "$f" "$PROCESSED_DIR/"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Processed: $(basename "$f")"
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] databridge-process cycle complete."

sleep infinity
EOF
chmod +x /usr/local/bin/databridge-process
echo "  Done."
echo ""

# --------------------------------------------------
# FIX 3: Cron job — add PATH so /usr/local/bin is reachable
# --------------------------------------------------
echo "[3/4] Fixing PATH in /etc/cron.d/databridge-cleanup..."

cat > /etc/cron.d/databridge-cleanup << 'EOF'
# DataBridge nightly cleanup
PATH=/usr/local/bin:/usr/bin:/bin
0 2 * * * user databridge-cleanup
EOF
chmod 644 /etc/cron.d/databridge-cleanup
echo "  Done."
echo ""

# --------------------------------------------------
# FIX 4: Health-check — replace kill -9 with systemctl restart
# --------------------------------------------------
echo "[4/4] Fixing recovery mechanism in databridge-healthcheck..."

cat > /usr/local/bin/databridge-healthcheck << 'EOF'
#!/bin/bash
set -euo pipefail

SERVICE=databridge
LOG=/var/log/databridge/healthcheck.log

exec >> "$LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running health check for $SERVICE..."

if ! systemctl is-active --quiet "$SERVICE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Service $SERVICE is not active. Restarting via systemctl..."
    systemctl restart "$SERVICE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] systemctl restart issued for $SERVICE."
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Service $SERVICE is healthy."
fi
EOF
chmod +x /usr/local/bin/databridge-healthcheck
echo "  Done."
echo ""

# --------------------------------------------------
# Verify service is running with correct env
# --------------------------------------------------
echo "------------------------------------------------------------"
echo "  VERIFICATION"
echo "------------------------------------------------------------"
echo ""

sleep 2

echo "--- Service status ---"
systemctl status databridge --no-pager -l | head -20
echo ""

echo "--- Environment loaded from config ---"
if systemctl show databridge --property=Environment | grep -q "BATCH_SIZE"; then
    echo "  PASS: Environment variables loaded from databridge.conf"
else
    # Check via the process env
    pid=$(systemctl show -p MainPID --value databridge 2>/dev/null || echo "")
    if [ -n "$pid" ] && [ "$pid" != "0" ] && [ -f "/proc/$pid/environ" ]; then
        if cat /proc/"$pid"/environ | tr '\0' '\n' | grep -q "BATCH_SIZE"; then
            echo "  PASS: BATCH_SIZE found in process environment"
        else
            echo "  NOTE: Verify env manually: sudo cat /proc/\$(systemctl show -p MainPID --value databridge)/environ | tr '\\0' '\\n'"
        fi
    fi
fi
echo ""

echo "============================================================"
echo "  ALL FIXES APPLIED"
echo "============================================================"
echo ""
echo "  Fix 1 — databridge.service"
echo "           EnvironmentFile: .cnf -> .conf"
echo ""
echo "  Fix 2 — databridge-process"
echo "           [ \"\$count\" > \"\$THRESHOLD\" ] -> [ \"\$count\" -gt \"\$THRESHOLD\" ]"
echo "           set -e -> set -euo pipefail"
echo ""
echo "  Fix 3 — /etc/cron.d/databridge-cleanup"
echo "           Added: PATH=/usr/local/bin:/usr/bin:/bin"
echo ""
echo "  Fix 4 — databridge-healthcheck"
echo "           kill -9 \$pid -> systemctl restart databridge"
echo "============================================================"