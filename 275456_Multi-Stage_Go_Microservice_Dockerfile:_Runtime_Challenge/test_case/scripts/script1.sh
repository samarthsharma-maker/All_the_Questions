#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/goapp-runtime/Dockerfile"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing Dockerfile."; exit 1; }

BAD=$(grep -E 'chmod 777' "$FILE")
GOOD=$(grep -E 'chmod \+x' "$FILE")

[[ -n "$BAD" ]] && { print_status "failed" "Unsafe chmod 777 still present."; exit 1; }
[[ -z "$GOOD" ]] && { print_status "failed" "Missing chmod +x."; exit 1; }

print_status "success" "Permissions fixed."
