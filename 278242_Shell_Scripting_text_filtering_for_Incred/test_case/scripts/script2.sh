#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

EXPECTED_IPS=(
    "45.33.21.156"
    "98.76.54.32"
    "185.220.101.33"
)

BASE_DIR="/home/user"
SCRIPT="${BASE_DIR}/unique_ips.sh"
OUTPUT_FILE="${BASE_DIR}/unique_ip.txt"

function test_unique_post_ips() {

    chmod +x "$SCRIPT"
    "$SCRIPT"
    for ip in "${EXPECTED_IPS[@]}"; do
        if ! grep -qx "$ip" "$OUTPUT_FILE"; then
            print_status "failed" "Lab Failed: Expected IP '$ip' missing from unique_ip.txt."
            exit 1
        fi
    done

    FILE_LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
    EXPECTED_COUNT=${#EXPECTED_IPS[@]}

    if [[ "$FILE_LINE_COUNT" -ne "$EXPECTED_COUNT" ]]; then
        print_status "failed" "Lab Failed: unique_ip.txt contains unexpected extra IPs."
        exit 1
    fi

    print_status "success" "Lab Passed: Correct unique POST IPs detected."
}

test_unique_post_ips
exit 0
