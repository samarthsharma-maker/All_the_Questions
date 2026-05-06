#!/bin/bash

set -euo pipefail
TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/_____"

# Enter the Content Here
# func function_name() {
#     :
# }

echo "Creating/updating ${TARGET_FILE} ..."
chown user:user "${TARGET_FILE}" 2>/dev/null || true
