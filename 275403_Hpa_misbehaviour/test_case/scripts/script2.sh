#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/event-normalizer-hpa.yaml"

[[ ! -f "$FILE" ]] && { 
    print_status "failed" "HPA file missing."
    exit 1
}

############################################
# Extract raw values
############################################
RAW_MIN=$(sed -n 's/.*minReplicas:[[:space:]]*\(.*\)/\1/p' "$FILE")
RAW_AVG=$(sed -n 's/.*averageUtilization:[[:space:]]*\(.*\)/\1/p' "$FILE")

EXPECTED_MIN=5
EXPECTED_AVG=20

############################################
# Reject ANY garbage — values MUST be pure digits
############################################
if ! [[ "$RAW_MIN" =~ ^[0-9]+$ ]]; then
    print_status "failed" "minReplicas contains invalid characters: $RAW_MIN"
    exit 1
fi

if ! [[ "$RAW_AVG" =~ ^[0-9]+$ ]]; then
    print_status "failed" "averageUtilization contains invalid characters: $RAW_AVG"
    exit 1
fi

############################################
# Now compare numerically
############################################
if [[ "$RAW_MIN" -ne "$EXPECTED_MIN" ]]; then
    print_status "failed" "Scalling Down Didn't Happen: :("
    exit 1
fi

if [[ "$RAW_AVG" -ne "$EXPECTED_AVG" ]]; then
    print_status "failed" "averageUtilization must be ${EXPECTED_AVG}, found ${RAW_AVG}"
    exit 1
fi

print_status "success" "HPA thresholds corrected correctly."
