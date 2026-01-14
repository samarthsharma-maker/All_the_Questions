#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/flaskapp-part1/Dockerfile"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing Dockerfile."; exit 1; }

# --- Test 1: Builder stage syntax ---
# Must contain: FROM python:3.12-slim AS builder
if ! grep -qE '^FROM[[:space:]]+python:3\.12-slim[[:space:]]+AS[[:space:]]+builder' "$FILE"; then
    print_status "failed" "Incorrect or missing builder-stage syntax (AS builder)."
    exit 1
fi

# --- Test 2: WORKDIR must be /app ---
WORKDIR=$(awk '/^WORKDIR/ {print $2}' "$FILE" | head -n1)
if [[ "$WORKDIR" != "/app" ]]; then
    print_status "failed" "Builder WORKDIR must be /app."
    exit 1
fi

# --- Test 3: requirements file must be requirements.txt ---
if ! grep -qE '^COPY[[:space:]]+requirements\.txt' "$FILE"; then
    print_status "failed" "Incorrect requirements file (should be requirements.txt)."
    exit 1
fi

# --- Test 4: Exposed port must be 5000 ---
PORT=$(awk '/^EXPOSE/ {print $2}' "$FILE")
if [[ "$PORT" != "5000" ]]; then
    print_status "failed" "Port must be EXPOSE 5000."
    exit 1
fi

print_status "success" "All Part 1 fixes are correct."
