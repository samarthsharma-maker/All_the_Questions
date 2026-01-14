#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/component-deployment.yaml"
EXP_APP="nova-app"

[[ ! -f "$FILE" ]] && { print_status "failed" "Deployment file missing."; exit 1; }

# Extract each app label ON ITS OWN LINE
awk '/^[[:space:]]*app:/ { print $2 }' "$FILE" | tr -d '\r' > /home/user/app_values.txt

# Validate each app value separately
while read -r val; do
    [[ "$val" != "$EXP_APP" ]] && {
        print_status "failed" "Deployment app label incorrect: expected '$EXP_APP'"
        rm /home/user/app_values.txt
        exit 1
    }
done < /home/user/app_values.txt


print_status "success" "Deployment app labels valid."

rm /home/user/app_values.txt