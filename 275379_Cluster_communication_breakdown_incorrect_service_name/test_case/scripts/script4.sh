#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

FILE="/home/user/component-pod.yaml"
EXP_APP="nova-app"

[[ ! -f "$FILE" ]] && { print_status "failed" "Pod file missing."; exit 1; }

awk '/^[[:space:]]*app:/ { print $2 }' "$FILE" | tr -d '\r' > /home/user/pod_apps.txt

while read -r val; do
    [[ "$val" != "$EXP_APP" ]] && {
        print_status "failed" "Pod app label incorrect: expected '$EXP_APP'."
        rm /home/user/pod_apps.txt
        exit 1
    }
done < /home/user/pod_apps.txt

print_status "success" "Pod name valid."

rm /home/user/pod_apps.txt