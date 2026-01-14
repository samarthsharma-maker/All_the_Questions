#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/goapp/Dockerfile"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing Dockerfile."; exit 1; }

# Must NOT contain "*** apk"
grep '\*\*\* apk' "$FILE" >/dev/null && {
    print_status "failed" "Invalid apk command (*** apk)."
    exit 1
}

# Must contain proper RUN apk command
FOUND=$(grep -E '^RUN apk add --no-cache git' "$FILE")

[[ -z "$FOUND" ]] && { print_status "failed" "RUN apk command missing or incorrect."; exit 1; }

print_status "success" "apk command valid."
