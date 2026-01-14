#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/goapp-runtime/Dockerfile"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing Dockerfile."; exit 1; }

BAD=$(grep -E 'APP_ENV:production' "$FILE")
GOOD=$(grep -E 'APP_ENV=production' "$FILE")

[[ -n "$BAD" ]] && { print_status "failed" "Incorrect APP_ENV syntax remains."; exit 1; }
[[ -z "$GOOD" ]] && { print_status "failed" "Correct APP_ENV not set."; exit 1; }

print_status "success" "Environment variable syntax valid."
