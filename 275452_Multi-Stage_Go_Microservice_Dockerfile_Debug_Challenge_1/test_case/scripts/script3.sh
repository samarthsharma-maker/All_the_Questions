#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/goapp/Dockerfile"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing Dockerfile."; exit 1; }

# GOARCH must use '='
FOUND=$(grep -E 'GOARCH=amd64' "$FILE")

[[ -z "$FOUND" ]] && { print_status "failed" "GOARCH syntax incorrect."; exit 1; }

print_status "success" "GOARCH syntax valid."
