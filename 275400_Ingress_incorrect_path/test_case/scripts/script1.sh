#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/orion-reports-ingress.yaml"

[[ ! -f "$FILE" ]] && {
    print_status "failed" "Ingress file missing.";
    exit 1;
}
if grep -E 'pathType:' "$FILE" | grep -vqE 'pathType:[[:space:]]*(Prefix|Exact|ImplementationSpecific)[[:space:]]*$'; then
    print_status "failed" "Invalid pathType used."
    exit 1
fi

# Check pathType was corrected
if ! grep -q 'pathType: Prefix' "$FILE"; then
    print_status "failed" "Configuration is incorrect."
    exit 1
fi

# Ensure old incorrect value is not present
if grep -q 'pathType: ImplementationSpecific' "$FILE"; then
    print_status "failed" "Incorrect configuration still present"
    exit 1
fi

print_status "success" "pathType corrected successfully."
