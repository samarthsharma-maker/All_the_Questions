#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/python-runtime/Dockerfile"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing Dockerfile."; exit 1; }

# --- Test 1: WORKDIR must NOT contain double slashes or invalid path ---
WORKDIR=$(awk '/^WORKDIR/ {print $2}' "$FILE" | head -n1)
if [[ "$WORKDIR" == *"//"* ]]; then
    print_status "failed" "Invalid WORKDIR (contains double slashes)."
    exit 1
fi

# --- Test 2: chmod 777 must NOT exist in runtime stage ---
if grep -qE 'chmod[[:space:]]+-R[[:space:]]+777' "$FILE"; then
    print_status "failed" "Insecure chmod -R 777 still present."
    exit 1
fi

# --- Test 3: ENV must not have spaces around '=' ---
if grep -qE '^ENV[[:space:]]+PY_ENV=.*[[:space:]].*' "$FILE"; then
    print_status "failed" "ENV PY_ENV has invalid spacing."
    exit 1
fi

# --- Test 4: EXPOSE must NOT be 9090 ---
PORT=$(awk '/^EXPOSE/ {print $2}' "$FILE" | tail -n1)
if [[ "$PORT" == "9090" ]]; then
    print_status "failed" "Incorrect EXPOSE port (9090)."
    exit 1
fi

# --- Test 5: CMD must be valid exec-form JSON array ---
if grep -qE '^CMD[[:space:]]+"python"[[:space:]]+"main\.py"' "$FILE"; then
    print_status "failed" "CMD must be in JSON exec-form (e.g., CMD [\"python\", \"main.py\"])."
    exit 1
fi

print_status "success" "All Part 2 runtime-stage fixes are correct."
