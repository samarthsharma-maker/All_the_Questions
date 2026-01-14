#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/stream-mapper.yaml"

[[ ! -f "$FILE" ]] && { print_status "failed" "HPA file missing."; exit 1; }

#########################################
# 1. averageUtilization must be exactly 20
#########################################
AVG=$(grep -Eq "maxReplicas:[[:space:]]*[0-9]+$" "$FILE" | awk '{print $2}')

if [[ "$AVG" != "20" ]]; then
    print_status "failed" "averageUtilization must be 20 but found: $AVG"
    exit 1
fi

###########################################################
# 2. maxReplicas should be 20)
###########################################################
MAX=$(grep -Eq "maxReplicas:[[:space:]]*[0-9]+$" "$FILE" | awk '{print $2}')

if [[ "$MAX" -lt 20  ]]; then
    print_status "failed" "Coudln't Scale enough"
    exit 1
fi
if [[ "$MAX" -gt 20  ]]; then
    print_status "failed" "Scaled too much"
    exit 1
fi


print_status "success" "HPA thresholds corrected correctly."
