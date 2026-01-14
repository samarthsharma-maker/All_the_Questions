#!/bin/bash
# Test: Verify Memory request and limit values in the Deployment manifest

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/data-processor-deployment.yaml"
MANIFEST="$TARGET_FILE"

if [[ ! -f "$MANIFEST" ]]; then
    print_status "failed" "Manifest file '$MANIFEST' not found."
    exit 1
fi

# Extract Memory request
REQ_MEM=$(awk '
  /requests:/ { flag_req=1; next }
  flag_req && /memory:/ {
      gsub(/"/, "", $2)
      print $2
      flag_req=0
  }
' "$MANIFEST")

# Extract Memory limit
LIM_MEM=$(awk '
  /limits:/ { flag_lim=1; next }
  flag_lim && /memory:/ {
      gsub(/"/, "", $2)
      print $2
      flag_lim=0
  }
' "$MANIFEST")

# Validate request memory
if [[ "$REQ_MEM" != "1Gi" ]]; then
    print_status "failed" "Memory request is '$REQ_MEM', expected '1Gi'."
    exit 1
fi

# Validate limit memory
if [[ "$LIM_MEM" != "4Gi" ]]; then
    print_status "failed" "Memory limit is '$LIM_MEM', expected '4Gi'."
    exit 1
fi

print_status "success" "Memory request and limit values are correct."
