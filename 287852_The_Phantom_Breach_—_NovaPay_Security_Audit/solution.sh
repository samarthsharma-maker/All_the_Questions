#!/bin/bash

BASE_DIR="/home/user"

# zombie_audit.sh
cat > "${BASE_DIR}/zombie_audit.sh" << 'EOF'
#!/bin/bash

REPORT="/home/user/zombie_report.txt"
> "$REPORT"

echo "[ZOMBIE PROCESSES]" >> "$REPORT"

zombie_found=false

for pid_dir in /proc/[0-9]*/; do
    pid=$(basename "$pid_dir")
    status_file="${pid_dir}status"

    [[ ! -f "$status_file" ]] && continue

    state=$(grep -m1 "^State:" "$status_file" 2>/dev/null | awk '{print $2}')

    if [[ "$state" == "Z" ]]; then
        ppid=$(grep -m1 "^PPid:" "$status_file" 2>/dev/null | awk '{print $2}')
        parent_name="unknown"
        if [[ -f "/proc/${ppid}/status" ]]; then
            parent_name=$(grep -m1 "^Name:" "/proc/${ppid}/status" 2>/dev/null | awk '{print $2}')
        fi
        printf "PID:%s \nPARENT:%s\n\n" "$pid" "$parent_name" >> "$REPORT"
        zombie_found=true
    fi
done

if [[ "$zombie_found" == false ]]; then
    echo "NONE" >> "$REPORT"
fi
EOF
chmod +x "${BASE_DIR}/zombie_audit.sh"

# Run
bash "${BASE_DIR}/zombie_audit.sh"