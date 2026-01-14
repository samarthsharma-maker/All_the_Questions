#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/goapp/Dockerfile"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing Dockerfile."; exit 1; }

# GOOS must use '=' not ':'
FOUND=$(grep -E 'GOOS=linux' "$FILE")

[[ -z "$FOUND" ]] && { print_status "failed" "GOOS syntax incorrect."; exit 1; }

print_status "success" "GOOS syntax valid."
