#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/service-d-deployment.yaml"
EXP_PORT="9090"

[[ ! -f "$FILE" ]] && { print_status "failed" "Missing file."; exit 1; }

extract_all_container_ports() {
    awk '
        /containerPort:/ {
            for (i=1; i<=NF; i++) {
                if ($i ~ /containerPort:/) {
                    split($i, a, ":")
                    if (a[2] != "") { print a[2]; next }
                    if ($(i+1) != "") { print $(i+1); next }
                }
            }
        }
    ' "$FILE" | tr -d '[:space:]\r'
}

ALL_PORTS=$(extract_all_container_ports)

for p in $ALL_PORTS; do
    [[ -z "$p" ]] && { print_status "failed" "Service D Deployment Port incorrect."; exit 1; }
    [[ "$p" != "$EXP_PORT" ]] && { print_status "failed" "Service D Deployment Port incorrect."; exit 1; }
done

# readinessProbe
RP=$(awk '
    /readinessProbe:/ { r=1 }
    r && /port:/ {
        for (i=1; i<=NF; i++) {
            if ($i ~ /port:/) {
                split($i, a, ":")
                if (a[2] != "") { print a[2]; exit }
                if ($(i+1) != "") { print $(i+1); exit }
            }
        }
    }
' "$FILE" | tr -d '[:space:]\r')

[[ "$RP" != "$EXP_PORT" ]] && { print_status "failed" "Service D Deployment Probe readiness incorrect."; exit 1; }

# livenessProbe
LP=$(awk '
    /livenessProbe:/ { l=1 }
    l && /port:/ {
        for (i=1; i<=NF; i++) {
            if ($i ~ /port:/) {
                split($i, a, ":")
                if (a[2] != "") { print a[2]; exit }
                if ($(i+1) != "") { print $(i+1); exit }
            }
        }
    }
' "$FILE" | tr -d '[:space:]\r')

[[ "$LP" != "$EXP_PORT" ]] && { print_status "failed" "Service D Deployment Probe liveness incorrect."; exit 1; }

print_status "success" "Service D valid."
