#!/bin/bash
# solution.sh — Applies all four fixes to the LogHarvest bash scripting lab.
# Run as: bash solution.sh

set -euo pipefail

BASE_DIR="/home/user/logharvest"

echo "============================================================"
echo "  LOGHARVEST BASH LAB -- APPLYING FIXES"
echo "============================================================"
echo ""

if [[ ! -d "$BASE_DIR" ]]; then
    echo "ERROR: $BASE_DIR not found. Run the setup script first." >&2
    exit 1
fi

# --------------------------------------------------
# FIX 1 + FIX 2: log-harvest
#   Fix 1: pipe into while --> process substitution
#   Fix 2: exec 2>&1 >file  --> exec >file 2>&1
# --------------------------------------------------
echo "[1/2] Writing corrected /home/user/log-harvest..."

cat > /home/user/log-harvest << EOF
#!/bin/bash
set -euo pipefail

LOG_DIRS=("${BASE_DIR}/logs/app" "${BASE_DIR}/logs/db" "${BASE_DIR}/logs/worker")
REPORT_DIR="${BASE_DIR}/reports"
SCRIPT_LOG="${BASE_DIR}/script-logs/harvest.log"
DATE=\$(date '+%Y-%m-%d')
REPORT_FILE="\${REPORT_DIR}/harvest_\${DATE}.txt"

# Fix 2: correct redirect order -- stdout first, then stderr to same destination
exec >"\$SCRIPT_LOG" 2>&1

echo "[\${DATE}] log-harvest starting"

total_errors=0

for dir in "\${LOG_DIRS[@]}"; do
    if [[ ! -d "\$dir" ]]; then
        echo "WARNING: directory not found: \$dir" >&2
        continue
    fi

    dir_errors=0

    # Fix 1: process substitution keeps the loop in the current shell
    # so variable changes to dir_errors are visible after the loop
    while IFS= read -r line; do
        dir_errors=\$((dir_errors + 1))
    done < <(grep -rh 'ERROR' "\$dir")

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
echo "  Done."
echo ""

# --------------------------------------------------
# FIX 3 + FIX 4: log-report
#   Fix 3: "${report_dirs[@]}" -- quoted array expansion
#   Fix 4: || [[ -n "\$service" ]] -- handle last line without newline
# --------------------------------------------------
echo "[2/2] Writing corrected /home/user/log-report..."

cat > /home/user/log-report << EOF
#!/bin/bash
set -euo pipefail

CSV_FILE="\${1:-${BASE_DIR}/reports/daily.csv}"

if [[ ! -f "\$CSV_FILE" ]]; then
    echo "ERROR: report file not found: \$CSV_FILE" >&2
    exit 1
fi

# Fix 3: quoted array expansion -- paths with spaces are preserved intact
report_dirs=("${BASE_DIR}/reports" "${BASE_DIR}/reports/archive")
for dir in "\${report_dirs[@]}"; do
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

# Fix 4: process substitution keeps totals in current shell scope;
# || [[ -n "\$service" ]] handles last line with no trailing newline
while IFS=',' read -r service date errors warns || [[ -n "\${service:-}" ]]; do
    line_count=\$((line_count + 1))
    total_errors=\$((total_errors + errors))
    total_warns=\$((total_warns + warns))
    printf "  %-12s %s  errors=%-4s warns=%s\n" "\$service" "\$date" "\$errors" "\$warns"
done < <(tail -n +2 "\$CSV_FILE")

echo ""
echo "Totals: errors=\${total_errors}  warns=\${total_warns}  services=\${line_count}"
EOF
chmod +x /home/user/log-report
echo "  Done."
echo ""

# --------------------------------------------------
# Run verification
# --------------------------------------------------
echo "------------------------------------------------------------"
echo "  VERIFICATION"
echo "------------------------------------------------------------"
echo ""

echo "--- Running log-harvest ---"
bash /home/user/log-harvest
DATE=$(date '+%Y-%m-%d')
REPORT_FILE="${BASE_DIR}/reports/harvest_${DATE}.txt"
if [[ -f "$REPORT_FILE" ]]; then
    echo ""
    echo "--- Harvest report ---"
    cat "$REPORT_FILE"
fi
echo ""

echo "--- Running log-report ---"
bash /home/user/log-report "${BASE_DIR}/reports/daily.csv"
echo ""

echo "============================================================"
echo "  ALL FIXES APPLIED"
echo "============================================================"
echo ""
echo "  Fix 1 -- log-harvest: pipe into while --> process substitution"
echo "  Fix 2 -- log-harvest: exec 2>&1 >file --> exec >file 2>&1"
echo "  Fix 3 -- log-report:  \${arr[@]} --> \"\${arr[@]}\""
echo "  Fix 4 -- log-report:  read loop missing || [[ -n \"\$service\" ]]"
echo "============================================================"