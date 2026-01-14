#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/goapp/Dockerfile"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing Dockerfile."; exit 1; }

# Expect correct completed Go base image tag
EXP_REGEX='^FROM golang:1\.22-[A-Za-z0-9._-]+ AS build'

LINE=$(grep -E "$EXP_REGEX" "$FILE")

[[ -z "$LINE" ]] && { print_status "failed" "Base image tag incorrect or incomplete."; exit 1; }

print_status "success" "Base image tag valid."
