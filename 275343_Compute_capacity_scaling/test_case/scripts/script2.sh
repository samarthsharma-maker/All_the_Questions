#!/bin/bash
# Test: Verify baseline and burst compute values in the workload-engine Deployment

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/batch-engine.yaml"
MANIFEST="$TARGET_FILE"

if [[ -z "$MANIFEST" ]]; then
    print_status "failed" "Manifest file missing."
    exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
    print_status "failed" "Deployment manifest not found."
    exit 1
fi

###########################################
# Extract baseline CPU (requests.cpu)
###########################################
REQ_CPU=$(awk '
  /requests:/ { flag_req=1; next }
  flag_req && /cpu:/ {
      gsub(/"/, "", $2)
      print $2
      flag_req=0
  }
' "$MANIFEST")

###########################################
# Extract burst CPU (limits.cpu)
###########################################
LIM_CPU=$(awk '
  /limits:/ { flag_lim=1; next }
  flag_lim && /cpu:/ {
      gsub(/"/, "", $2)
      print $2
      flag_lim=0
  }
' "$MANIFEST")

###########################################
# Extract baseline Memory (requests.memory)
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
# Extract burst Memory (limits.memory)
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
# Expected normalized values
###########################################
EXP_REQ_CPU_M=250       # 250m
EXP_LIM_CPU_M=1000      # 1000m OR 1 CPU
EXP_REQ_MEM_MI=512      # 512Mi
EXP_LIM_MEM_MI=2048     # 2Gi

###########################################
# Convert memory to Mi
###########################################
to_mi() {
    local val="$1"

    if [[ "$val" =~ ^([0-9]+)Mi$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi

    if [[ "$val" =~ ^([0-9]+)Gi$ ]]; then
        echo $(( ${BASH_REMATCH[1]} * 1024 ))
        return
    fi

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
# Convert CPU to millicores
###########################################
to_mcpu() {
    local cpu="$1"

    if [[ "$cpu" =~ ^([0-9]+)m$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi

    if [[ "$cpu" =~ ^([0-9]+)$ ]]; then
        echo $(( cpu * 1000 ))
        return
    fi

    echo "invalid"
}

###########################################
# Normalize extracted values
###########################################
N_REQ_CPU=$(to_mcpu "$REQ_CPU")
N_LIM_CPU=$(to_mcpu "$LIM_CPU")
N_REQ_MEM=$(to_mi "$REQ_MEM")
N_LIM_MEM=$(to_mi "$LIM_MEM")

###########################################
# Validations (generic, safe messages)
###########################################

if [[ "$N_REQ_CPU" != "$EXP_REQ_CPU_M" ]]; then
    print_status "failed" "Incorrect baseline CPU value."
    exit 1
fi

if [[ "$N_LIM_CPU" != "$EXP_LIM_CPU_M" ]]; then
    print_status "failed" "Incorrect burst CPU value."
    exit 1
fi

if [[ "$N_REQ_MEM" != "$EXP_REQ_MEM_MI" ]]; then
    print_status "failed" "Incorrect baseline memory value."
    exit 1
fi

if [[ "$N_LIM_MEM" != "$EXP_LIM_MEM_MI" ]]; then
    print_status "failed" "Incorrect burst memory value."
    exit 1
fi

print_status "success" "Compute baseline and burst values are correct."
exit 0
