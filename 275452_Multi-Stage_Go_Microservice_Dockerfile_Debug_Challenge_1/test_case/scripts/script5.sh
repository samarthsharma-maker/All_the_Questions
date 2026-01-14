#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/goapp/Dockerfile"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing Dockerfile."; exit 1; }

LINE_MOD=$(grep -n 'COPY go\.mod go\.sum' "$FILE" | cut -d: -f1)
LINE_SRC=$(grep -n 'COPY \. \.' "$FILE" | cut -d: -f1)

[[ -z "$LINE_MOD" || -z "$LINE_SRC" ]] && {
    print_status "failed" "Required COPY statements missing.";
    exit 1;
}

(( LINE_MOD < LINE_SRC )) || {
    print_status "failed" "Incorrect COPY order — go.mod/go.sum must come first.";
    exit 1;
}

print_status "success" "COPY order valid."
