#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/service-a-deployment.yaml"
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
RP=$(awk '
    /readinessProbe:/ {r=1}
    r && /port:/ {
        for (i=1; i<=NF; i++) {
            if ($i ~ /port:/) {
                split($i, a, ":");
                if (a[2] != "") { print a[2]; exit }
                if ($(i+1) != "") { print $(i+1); exit }
            }
        }
    }
' "$FILE" | tr -d '[:space:]\r')

[[ "$CP" != "$EXP_PORT" ]] && { print_status "failed" "Service A Deployment Port incorrect."; exit 1; }
[[ "$RP" != "$EXP_PORT" ]] && { print_status "failed" "Service A Deployment Probe incorrect."; exit 1; }

print_status "success" "Service A valid."
