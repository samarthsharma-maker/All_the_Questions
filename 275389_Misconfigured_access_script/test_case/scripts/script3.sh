#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/John_Configuration_context.sh"

[[ ! -f "$FILE" ]] && { print_status "failed" "Configuration file missing."; exit 1; }

# Expect exactly 3 lines
LINE_COUNT=$(wc -l < "$FILE")
[[ "$LINE_COUNT" -ne 3 ]] && {
    print_status "failed" "File must contain exactly 3 commands."
    exit 1
}

# Check credentials command validity
grep -q '^kubectl config set-credentials John ' "$FILE" || {
    print_status "failed" "Credentials command modified incorrectly."
    exit 1
}

# Ensure no invalid flags in the file
if grep -qE 'cluster_type=' "$FILE"; then
    print_status "failed" "Invalid cluster flag found: cluster_type"
    exit 1
fi

print_status "success" "All other commands and structure valid."
