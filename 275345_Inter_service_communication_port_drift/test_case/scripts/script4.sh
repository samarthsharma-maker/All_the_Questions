#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/service-c-pod.yaml"
EXP_PORT="9090"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing file."; exit 1; }

CP=$(awk '
    /containerPort:/ {
        for (i=1; i<=NF; i++) {
            if ($i ~ /containerPort:/) {
                split($i, a, ":")
                if (a[2] != "") { print a[2]; exit }
                if ($(i+1) != "") { print $(i+1); exit }
            }
        }
    }
' "$FILE" | tr -d '[:space:]\r')

[[ "$CP" != "$EXP_PORT" ]] && { print_status "failed" "Service C Pod Port incorrect."; exit 1; }

print_status "success" "Service C valid."
