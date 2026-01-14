#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/event-normalizer-hpa.yaml"
TMP_DIR="/home/user/tmp"
BASELINE="$TMP_DIR/baseline.yaml"
STUDENT_FIXED="$TMP_DIR/student_fixed.yaml"
BASE_FIXED="$TMP_DIR/base_fixed.yaml"

###############################################
# Setup temp directory
###############################################
mkdir -p "$TMP_DIR"

cleanup() {
    rm -f "$BASELINE" "$STUDENT_FIXED" "$BASE_FIXED"
}
trap cleanup EXIT

###############################################
# Validate file exists
###############################################
[[ ! -f "$FILE" ]] && { 
    print_status "failed" "HPA file missing."
    exit 1
}

###############################################
# Create strict baseline (only 2 allowed changes)
###############################################
cat <<EOF > "$BASELINE"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: event-normalizer-hpa
spec:
  minReplicas: __ALLOW_CHANGE__
  maxReplicas: 30
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: __ALLOW_CHANGE__
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: event-normalizer
EOF

###############################################
# Strip out allowed-change lines
###############################################
grep -v -E 'minReplicas:|averageUtilization:' "$FILE"     > "$STUDENT_FIXED"
grep -v -E 'minReplicas:|averageUtilization:' "$BASELINE" > "$BASE_FIXED"

###############################################
# Compare — ANY other change = fail
###############################################
if ! diff -q "$STUDENT_FIXED" "$BASE_FIXED" >/dev/null 2>&1; then
    print_status "failed" "Unallowed configuration changes detected."
    exit 1
fi

###############################################
# Now validate the two allowed fields changed
###############################################
CUR_MIN=$(sed -n 's/.*minReplicas:[[:space:]]*\([0-9]\+\).*/\1/p' "$FILE")
CUR_AVG=$(sed -n 's/.*averageUtilization:[[:space:]]*\([0-9]\+\).*/\1/p' "$FILE")

if [[ -z "$CUR_MIN" || -z "$CUR_AVG" ]]; then
    print_status "failed" "Missing minReplicas or averageUtilization."
    exit 1
fi

if [[ "$CUR_MIN" == "25" ]]; then
    print_status "failed" "minReplicas must be changed."
    exit 1
fi

if [[ "$CUR_AVG" == "80" ]]; then
    print_status "failed" "averageUtilization must be changed."
    exit 1
fi

print_status "success" "Only allowed HPA fields modified; structure intact."


