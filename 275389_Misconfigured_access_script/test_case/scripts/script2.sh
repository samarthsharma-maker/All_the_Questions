#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/John_Configuration_context.sh"

[[ ! -f "$FILE" ]] && { print_status "failed" "Configuration file missing."; exit 1; }

# Extract set-context line
SET_CTX_LINE=$(grep -E 'kubectl config set-context' "$FILE" | tr -d '\r')

# Extract use-context line
USE_CTX_LINE=$(grep -E 'kubectl config use-context' "$FILE" | tr -d '\r')

# 1. Check if set-context exists
[[ -z "$SET_CTX_LINE" ]] && {
    print_status "failed" "Missing 'set-context' command."
    exit 1
}

# 2. Ensure no arguments were incorrectly placed in use-context
if echo "$USE_CTX_LINE" | grep -qE -- '--cluster|--namespace|--user'; then
    print_status "failed" "Incorrect use of 'use-context' with configuration flags."
    exit 1
fi

print_status "success" "Context command usage valid."
