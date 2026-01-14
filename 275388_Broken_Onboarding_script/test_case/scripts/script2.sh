#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/John_Configuration_context.sh"
EXPECTED_CLUSTER="--cluster=kubernetes"

[[ ! -f "$FILE" ]] && {
    print_status "failed" "Configuration file missing."
    exit 1
}

# Extract cluster flag using sed
# This captures: --cluster=something
CLUSTER_VALUE=$(sed -n 's/.*\(--cluster=[a-zA-Z0-9_-]\+\).*/\1/p' "$FILE" | tr -d '\r')

# If user has not fixed --cluster_type → this will be empty
[[ -z "$CLUSTER_VALUE" ]] && {
    print_status "failed" "Cluster flag missing or still incorrect."
    exit 1
}

# Validate correct cluster value
[[ "$CLUSTER_VALUE" != "$EXPECTED_CLUSTER" ]] && {
    print_status "failed" "Cluster incorrect: expected 'kubernetes'"
    exit 1
}

print_status "success" "Cluster flag correctly updated to '--cluster=kubernetes'."
