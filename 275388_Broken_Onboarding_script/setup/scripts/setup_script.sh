#!/bin/bash

set -euo pipefail

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/John_Configuration_context.sh"

echo "Creating/updating ${TARGET_FILE} ..."

mkdir -p "${TARGET_DIR}"

cat <<EOF > "${TARGET_FILE}"
kubectl config set-credentials John --client-key=/root/users/john.key --client-certificate=/root/users/john.crt
kubectl config set-context john-context --cluster_type=kubernetes --namespace=scaller --user=John
kubectl config use-context john-context
EOF

# Create dummy key + cert directory
mkdir -p /root/users
echo "dummy-key" > /root/users/john.key
echo "dummy-cert" > /root/users/john.crt

# Safe owner change in case platform doesn't support chown
chown user:user "${TARGET_FILE}" 2>/dev/null || true
