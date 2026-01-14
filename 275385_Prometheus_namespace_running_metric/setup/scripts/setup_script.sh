#!/bin/bash

set -euo pipefail

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/PromQL.sh"

echo "Creating/updating ${TARGET_FILE} ..."

mkdir -p "${TARGET_DIR}"

touch "${TARGET_FILE}"

# Safe owner change in case platform doesn't support chown
chown user:user "${TARGET_FILE}" 2>/dev/null || true
