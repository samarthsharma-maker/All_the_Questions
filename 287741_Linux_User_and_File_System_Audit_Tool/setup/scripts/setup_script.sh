#!/bin/bash

BASE_DIR="/home/user"
AUDIT_ZONE="${BASE_DIR}/audit_zone"
cd "$BASE_DIR"
touch audit_report.txt
chmod 777 audit_report.txt

# Create the audit zone directory
mkdir -p "$AUDIT_ZONE"
chown user:user "$AUDIT_ZONE"

# Create files owned by valid users
touch "${AUDIT_ZONE}/valid_file_1.txt"
touch "${AUDIT_ZONE}/valid_file_2.conf"

# Create orphaned files by assigning non-existent UIDs
touch "${AUDIT_ZONE}/orphan_alpha.txt"
touch "${AUDIT_ZONE}/orphan_beta.log"
mkdir -p "${AUDIT_ZONE}/orphan_dir"
chown 9901:9901 "${AUDIT_ZONE}/orphan_alpha.txt"
chown 9902:9902 "${AUDIT_ZONE}/orphan_beta.log"
chown 9903:9903 "${AUDIT_ZONE}/orphan_dir"

# Create non-system users for the audit (UID >= 1000)
useradd -m -u 1101 -s /bin/bash alice   2>/dev/null || true
useradd -m -u 1102 -s /bin/bash bob     2>/dev/null || true
useradd -m -u 1103 -s /bin/bash charlie 2>/dev/null || true

# Grant alice and charlie sudo access via sudoers.d
echo "alice ALL=(ALL:ALL) ALL"   > /etc/sudoers.d/alice
echo "charlie ALL=(ALL:ALL) ALL" > /etc/sudoers.d/charlie
chmod 440 /etc/sudoers.d/alice
chmod 440 /etc/sudoers.d/charlie

# bob has no sudo access

echo "Setup complete."