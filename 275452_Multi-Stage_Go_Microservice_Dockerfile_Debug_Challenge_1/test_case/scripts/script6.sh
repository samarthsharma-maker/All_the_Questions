#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/goapp/Dockerfile"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing Dockerfile."; exit 1; }

# All ENV vars must be correct
CGO=$(grep -E 'CGO_ENABLED=0' "$FILE")
GOOS=$(grep -E 'GOOS=linux' "$FILE")
GOARCH=$(grep -E 'GOARCH=amd64' "$FILE")

[[ -z "$CGO" ]] && { print_status "failed" "CGO flag incorrect."; exit 1; }
[[ -z "$GOOS" ]] && { print_status "failed" "GOOS flag incorrect."; exit 1; }
[[ -z "$GOARCH" ]] && { print_status "failed" "GOARCH flag incorrect."; exit 1; }

print_status "success" "Static build environment variables valid."
