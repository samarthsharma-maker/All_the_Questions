#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/goapp-runtime/Dockerfile"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing Dockerfile."; exit 1; }

BAD=$(grep -E 'CMD \["server"\]' "$FILE")
GOOD=$(grep -E 'CMD \["\./server"\]' "$FILE")

[[ -n "$BAD" ]] && { print_status "failed" "Incorrect CMD format (missing ./)."; exit 1; }
[[ -z "$GOOD" ]] && { print_status "failed" "Correct CMD not found."; exit 1; }

print_status "success" "CMD format valid."
