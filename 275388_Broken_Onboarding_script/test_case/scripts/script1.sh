#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/John_Configuration_context.sh"
EXPECTED_NS="--namespace=scaler"

[[ ! -f "$FILE" ]] && { print_status "failed" "Configuration file missing."; exit 1; }

# Extract namespace using sed (works on BusyBox)
NS_VALUE=$(sed -n 's/.*\(--namespace=[a-zA-Z0-9_-]\+\).*/\1/p' "$FILE" | tr -d '\r')

[[ -z "$NS_VALUE" ]] && {
    print_status "failed" "Namespace flag missing."
    exit 1
}

[[ "$NS_VALUE" != "$EXPECTED_NS" ]] && {
    print_status "failed" "Namespace incorrect: expected Namespace to be scaler"
    exit 1
}

print_status "success" "Namespace value valid."
