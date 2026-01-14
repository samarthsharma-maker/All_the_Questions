#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/orion-reports-ingress.yaml"

[[ ! -f "$FILE" ]] && {
    print_status "failed" "Ingress file missing.";
    exit 1;
}

# rewrite-target annotation unchanged
grep -q 'nginx.ingress.kubernetes.io/rewrite-target: /' "$FILE" || {
    print_status "failed" "rewrite-target annotation modified or missing."
    exit 1
}

# metadata.name unchanged
grep -q '^  name: orion-reports-ingress' "$FILE" || {
    print_status "failed" "Ingress name modified."
    exit 1
}

# host unchanged
grep -q 'host: reports.internal.company.com' "$FILE" || {
    print_status "failed" "Host value modified."
    exit 1
}

# backend service name unchanged
grep -q 'name: orion-reports-service' "$FILE" || {
    print_status "failed" "Backend service name modified."
    exit 1
}

# backend port unchanged
grep -q 'number: 9000' "$FILE" || {
    print_status "failed" "Backend port modified."
    exit 1
}

print_status "success" "All other Ingress configuration values untouched and valid."
