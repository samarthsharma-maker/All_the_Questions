#!/bin/env bash

BASE_DIR="/home/user"
AUDIT_SCRIPT="${BASE_DIR}/sys_audit.sh"

cat > "${AUDIT_SCRIPT}" << 'EOF'
#!/bin/bash

BASE_DIR="/home/user"
AUDIT_DIR="${BASE_DIR}/audit_zone"
OUTPUT_FILE="${BASE_DIR}/audit_report.txt"

> "$OUTPUT_FILE"

# -------------------------------------------------------
# SECTION 1: Orphaned File Detection
# -------------------------------------------------------
echo "[ORPHANED FILES]" >> "$OUTPUT_FILE"

orphaned=$(find "$AUDIT_DIR" -nouser 2>/dev/null)

if [ -z "$orphaned" ]; then
    echo "NONE" >> "$OUTPUT_FILE"
else
    echo "$orphaned" >> "$OUTPUT_FILE"
fi

# -------------------------------------------------------
# SECTION 2: Sudo Privilege Audit
# -------------------------------------------------------
echo "[SUDO AUDIT]" >> "$OUTPUT_FILE"

qualifying_users=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | sort)

if [ -z "$qualifying_users" ]; then
    echo "NONE" >> "$OUTPUT_FILE"
else
    while IFS= read -r username; do
        if grep -rq "^${username}" /etc/sudoers /etc/sudoers.d/ 2>/dev/null; then
            echo "$username  SUDO:YES" >> "$OUTPUT_FILE"
        else
            echo "$username  SUDO:NO" >> "$OUTPUT_FILE"
        fi
    done <<< "$qualifying_users"
fi
EOF

chmod +x "${AUDIT_SCRIPT}"