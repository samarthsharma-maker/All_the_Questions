#!/bin/bash
# Test: Verify CPU request and limit values in the Deployment manifest
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/data-processor-deployment.yaml"
MANIFEST="$TARGET_FILE"

if [[ -z "$MANIFEST" ]]; then
    print_status "failed" "No manifest file provided."
    exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
    print_status "failed" "Manifest file '$MANIFEST' not found."
    exit 1
fi

# Extract CPU request
REQ_CPU=$(awk '
  /requests:/ { flag_req=1; next }
  flag_req && /cpu:/ {
      gsub(/"/, "", $2)
      print $2
      flag_req=0
  }
' "$MANIFEST")

# Extract CPU limit
LIM_CPU=$(awk '
  /limits:/ { flag_lim=1; next }
  flag_lim && /cpu:/ {
      gsub(/"/, "", $2)
      print $2
      flag_lim=0
  }
' "$MANIFEST")

# Validate request CPU
if [[ "$REQ_CPU" != "500m" ]]; then
    print_status "failed" "CPU request is '$REQ_CPU', expected '500m'."
    exit 1
fi

# Validate limit CPU
if [[ "$LIM_CPU" != "2" ]]; then
    print_status "failed" "CPU limit is '$LIM_CPU', expected '2'."
    exit 1
fi

print_status "success" "CPU request and limit values are correct."
