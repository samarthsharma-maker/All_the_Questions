#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/goapp-runtime/Dockerfile"
EXP_PORT="8080"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing Dockerfile."; exit 1; }

PORT=$(grep -E '^EXPOSE ' "$FILE" | awk '{print $2}' | tr -d '[:space:]')

[[ "$PORT" != "$EXP_PORT" ]] && { print_status "failed" "Incorrect EXPOSE port."; exit 1; }

print_status "success" "EXPOSE port correct."
