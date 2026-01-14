#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/John_Configuration_context.sh"

[[ ! -f "$FILE" ]] && { print_status "failed" "Configuration file missing."; exit 1; }

# Ensure exactly 3 lines
LINE_COUNT=$(wc -l < "$FILE")
[[ "$LINE_COUNT" -ne 3 ]] && {
    print_status "failed" "File must contain exactly 3 commands."
    exit 1
}

CONTENT=$(sed 's/[[:space:]]\+$//' "$FILE" | tr -d '\r')

# Check 1: set-credentials unchanged
grep -q 'kubectl config set-credentials John --client-key=/root/users/john.key --client-certificate=/root/users/john.crt' <<< "$CONTENT" || {
    print_status "failed" "set-credentials command modified incorrectly."
    exit 1
}

# Check 2: set-context john-context (except cluster/ns validated separately)
grep -q 'kubectl config set-context john-context' <<< "$CONTENT" || {
    print_status "failed" "set-context john-context missing or modified."
    exit 1
}

# Check 3: use-context john-context
grep -q 'kubectl config use-context john-context' <<< "$CONTENT" || {
    print_status "failed" "use-context john-context missing or modified."
    exit 1
}

print_status "success" "All other commands and structure valid."
