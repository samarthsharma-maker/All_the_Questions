#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/orion-panel-ingress.yaml"

[[ ! -f "$FILE" ]] && { 
    print_status "failed" "Ingress file missing."; 
    exit 1; 
}

# Ensure canary annotations are removed
if grep -q 'nginx.ingress.kubernetes.io/canary' "$FILE"; then
    print_status "failed" "Canary configuration still present."
    exit 1
fi

if grep -q 'nginx.ingress.kubernetes.io/canary-weight' "$FILE"; then
    print_status "failed" "Canary weight field still present."
    exit 1
fi

print_status "success" "Canary configuration removed successfully."
