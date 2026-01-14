#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/service-b-replicaset.yaml"
EXP_PORT="9090"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing file."; exit 1; }

extract_port() {
    awk '
        /'"$1"':/ {
            for (i=1; i<=NF; i++) {
                if ($i ~ /'"$1"':/) {
                    split($i, a, ":");
                    if (a[2] != "") { print a[2]; exit }
                    if ($(i+1) != "") { print $(i+1); exit }
                }
            }
        }
    ' "$FILE" | tr -d '[:space:]\r'
}

CP=$(extract_port "containerPort")
LP=$(awk '
    /livenessProbe:/ {l=1}
    l && /port:/ {
        for (i=1; i<=NF; i++) {
            if ($i ~ /port:/) {
                split($i, a, ":");
                if (a[2] != "") { print a[2]; exit }
                if ($(i+1) != "") { print $(i+1); exit }
            }
        }
    }
' "$FILE" | tr -d '[:space:]\r')

[[ "$CP" != "$EXP_PORT" ]] && { print_status "failed" "Service B Replicaset Port incorrect."; exit 1; }
[[ "$LP" != "$EXP_PORT" ]] && { print_status "failed" "Service B Replicaset incorrect."; exit 1; }

print_status "success" "Service B valid."
