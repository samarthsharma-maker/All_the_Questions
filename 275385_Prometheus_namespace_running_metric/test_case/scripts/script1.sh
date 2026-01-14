#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/PromQL.sh"

# Canonical expected form (normalized later)
EXPECTED='count by (namespace) (kube_pod_status_phase{phase="Running"})'
EXPECTED_ALT='sum by (namespace) (kube_pod_status_phase{phase="Running"} == 1)'
# 1. Ensure file exists
[[ ! -f "$FILE" ]] && { print_status "failed" "Missing PromQL.sh file."; exit 1; }

# 2. Read file, strip CR, trim whitespace, remove empty lines
SANITIZED=$(sed 's/\r//g' "$FILE" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')

# 3. Ensure non-empty
[[ -z "$SANITIZED" ]] && { print_status "failed" "PromQL query missing."; exit 1; }

# 4. Normalize user query:
#    - Convert tabs/newlines to spaces
#    - Collapse multiple spaces
#    - Normalize "{ key = value }" → "{key=value}"
NORMALIZED=$(echo "$SANITIZED" \
  | tr '\n\t' '  ' \
  | sed 's/[[:space:]]\+/ /g' \
  | sed 's/{[[:space:]]*/{/g; s/[[:space:]]*}/}/g' \
  | sed 's/[[:space:]]*=[[:space:]]*/=/g' \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

# 5. Normalize expected form the same way
EXPECTED_NORM_1=$(echo "$EXPECTED" \
  | sed 's/[[:space:]]\+/ /g' \
  | sed 's/{[[:space:]]*/{/g; s/[[:space:]]*}/}/g' \
  | sed 's/[[:space:]]*=[[:space:]]*/=/g')

# Expected alternative normalization
EXPECTED_NORM_2=$(echo "$EXPECTED_ALT" \
  | sed 's/[[:space:]]\+/ /g' \
  | sed 's/{[[:space:]]*/{/g; s/[[:space:]]*}/}/g' \
  | sed 's/[[:space:]]*=[[:space:]]*/=/g')

# 6. Compare
if [[ "$NORMALIZED" == "$EXPECTED_NORM_1" ]]; then
    print_status "success" "PromQL query valid."
    exit 0
fi

if [[ "$NORMALIZED" == "$EXPECTED_NORM_2" ]]; then
    print_status "success" "PromQL query valid."
    exit 0
fi


print_status "failed" "Incorrect PromQL query."
exit 1