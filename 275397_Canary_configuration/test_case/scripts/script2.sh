#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/orion-panel-ingress.yaml"

[[ ! -f "$FILE" ]] && { 
    print_status "failed" "Ingress file missing."; 
    exit 1; 
}

# --- Required top-level structure ---
grep -q '^apiVersion: networking.k8s.io/v1' "$FILE" || {
    print_status "failed" "apiVersion missing or modified."
    exit 1
}

grep -q '^kind: Ingress' "$FILE" || {
    print_status "failed" "kind missing or modified."
    exit 1
}

# Validate metadata.name (correct indent)
grep -q '^metadata:' "$FILE" || {
    print_status "failed" "metadata block missing."
    exit 1
}

grep -q '^  name: orion-panel-ingress' "$FILE" || {
    print_status "failed" "Ingress name modified."
    exit 1
}

# --- Required annotations ---
grep -q '^  annotations:' "$FILE" || {
    print_status "failed" "annotations block missing."
    exit 1
}

grep -q 'nginx.ingress.kubernetes.io/rewrite-target: /' "$FILE" || {
    print_status "failed" "rewrite-target annotation missing or modified."
    exit 1
}

# --- Validate rules block exists ---
grep -q '^  rules:' "$FILE" || {
    print_status "failed" "rules block missing."
    exit 1
}

grep -q 'host: orion.internal.company.com' "$FILE" || {
    print_status "failed" "Host value modified."
    exit 1
}

# --- Backend checks ---
grep -q '^              service:' "$FILE" || {
    print_status "failed" "service block missing under backend."
    exit 1
}

grep -q 'name: orion-panel-service' "$FILE" || {
    print_status "failed" "Backend service name modified."
    exit 1
}

grep -q 'number: 8080' "$FILE" || {
    print_status "failed" "Backend service port modified."
    exit 1
}

print_status "success" "Ingress structure and remaining configuration intact."
