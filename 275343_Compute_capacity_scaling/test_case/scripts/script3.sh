#!/bin/bash
# Test: Verify Memory baseline and burst values in the batch-engine manifest

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/batch-engine.yaml"
MANIFEST="$TARGET_FILE"

if [[ ! -f "$MANIFEST" ]]; then
    print_status "failed" "Manifest file not found."
    exit 1
fi

###########################################
# Extract Memory request (baseline)
###########################################
REQ_MEM=$(awk '
  /requests:/ { flag_req=1; next }
  flag_req && /memory:/ {
      gsub(/"/, "", $2)
      print $2
      flag_req=0
  }
' "$MANIFEST")

###########################################
# Extract Memory limit (burst)
###########################################
LIM_MEM=$(awk '
  /limits:/ { flag_lim=1; next }
  flag_lim && /memory:/ {
      gsub(/"/, "", $2)
      print $2
      flag_lim=0
  }
' "$MANIFEST")

###########################################
# Expected Memory Values (normalized)
###########################################
EXP_REQ_MI=512      # 512Mi
EXP_LIM_MI=2048     # 2Gi

###########################################
# Convert memory to Mi
###########################################
to_mi() {
    local val="$1"

    # e.g., 512Mi
    if [[ "$val" =~ ^([0-9]+)Mi$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi

    # e.g., 2Gi
    if [[ "$val" =~ ^([0-9]+)Gi$ ]]; then
        echo $(( ${BASH_REMATCH[1]} * 1024 ))
        return
    fi

    # e.g., 2.5Gi
    if [[ "$val" =~ ^([0-9]+)\.([0-9]+)Gi$ ]]; then
        whole="${BASH_REMATCH[1]}"
        frac="${BASH_REMATCH[2]}"
        len="${#frac}"
        echo $(( whole * 1024 + frac * 1024 / (10 ** len) ))
        return
    fi

    echo "invalid"
}

###########################################
# Normalize extracted values
###########################################
N_REQ_MEM=$(to_mi "$REQ_MEM")
N_LIM_MEM=$(to_mi "$LIM_MEM")

###########################################
# Validations (generic errors, no answers revealed)
###########################################

if [[ "$N_REQ_MEM" != "$EXP_REQ_MI" ]]; then
    print_status "failed" "Incorrect baseline memory value."
    exit 1
fi

if [[ "$N_LIM_MEM" != "$EXP_LIM_MI" ]]; then
    print_status "failed" "Incorrect burst memory value."
    exit 1
fi

print_status "success" "Memory baseline and burst values are correct."
exit 0
