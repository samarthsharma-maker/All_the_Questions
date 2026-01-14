#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/stream-mapper.yaml"

[[ ! -f "$FILE" ]] && { print_status "failed" "HPA file missing."; exit 1; }

# File must still contain exactly 17 lines
EXPECTED_LINES=18
ACTUAL_LINES=$(wc -l < "$FILE")

if [[ "$ACTUAL_LINES" -ne "$EXPECTED_LINES" ]]; then
    print_status "failed" "Unexpected file structure. Only two values should be changed."
    exit 1
fi

# Check the core structure is still present, but allow indentation
REQUIRED_STRINGS=(
  "apiVersion: autoscaling/v2"
  "kind: HorizontalPodAutoscaler"
  "name: stream-mapper-hpa"
  "minReplicas: 1"
  "metrics:"
  "type: Utilization"
  "scaleTargetRef:"
  "kind: Deployment"
  "name: stream-mapper"
)

for str in "${REQUIRED_STRINGS[@]}"; do
    if ! grep -q "$str" "$FILE"; then
        print_status "failed" "Structure modified unexpectedly (missing: $str)"
        exit 1
    fi
done

print_status "success" "All non-threshold fields remain unchanged."
