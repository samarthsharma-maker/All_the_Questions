#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/goapp-runtime/Dockerfile"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing Dockerfile."; exit 1; }

BAD=$(grep -E 'USER 1000:1010' "$FILE")
GOOD=$(grep -E 'USER 1000:1000' "$FILE")

[[ -n "$BAD" ]] && { print_status "failed" "Incorrect UID:GID still present."; exit 1; }
[[ -z "$GOOD" ]] && { print_status "failed" "Correct UID:GID not set."; exit 1; }

print_status "success" "User configuration valid."
