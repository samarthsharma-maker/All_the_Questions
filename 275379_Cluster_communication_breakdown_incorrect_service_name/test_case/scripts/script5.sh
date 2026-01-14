#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/component-service.yaml"
EXP_APP="nova-app"

[[ ! -f "$FILE" ]] && { print_status "failed" "Service file missing."; exit 1; }

awk '/^[[:space:]]*app:/ { print $2 }' "$FILE" | tr -d '\r' > /home/user/svc_apps.txt

while read -r val; do
    [[ "$val" != "$EXP_APP" ]] && {
        print_status "failed" "Service app label incorrect: expected '$EXP_APP'."
        rm /home/user/svc_apps.txt
        exit 1
    }
done < /home/user/svc_apps.txt

print_status "success" "Service name valid."

rm /home/user/svc_apps.txt