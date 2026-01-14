#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

# Expected output: IPs with 3 or more failed login attempts
EXPECTED_OUTPUT=(
    "3 98.76.54.32"
    "3 45.33.21.156"
)

BASE_DIR="/home/user"
SCRIPT="${BASE_DIR}/failed_logins.sh"
OUTPUT_FILE="${BASE_DIR}/suspicious_ips.txt"

function test_suspicious_ips() {

    chmod +x "$SCRIPT"
    "$SCRIPT"
    
    # Check if output file has correct number of lines
    FILE_LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
    EXPECTED_COUNT=${#EXPECTED_OUTPUT[@]}

    if [[ "$FILE_LINE_COUNT" -ne "$EXPECTED_COUNT" ]]; then
        print_status "failed" "Lab Failed: suspicious_ips.txt contains $FILE_LINE_COUNT lines, expected $EXPECTED_COUNT."
        exit 1
    fi

    # Check if each expected line exists in the output
    for expected_line in "${EXPECTED_OUTPUT[@]}"; do
        if ! grep -qF "$expected_line" "$OUTPUT_FILE"; then
            print_status "failed" "Lab Failed: Expected line '$expected_line' missing from suspicious_ips.txt."
            exit 1
        fi
    done

    # Verify sorting order (descending by count)
    FIRST_LINE=$(head -n 1 "$OUTPUT_FILE")
    FIRST_COUNT=$(echo "$FIRST_LINE" | awk '{print $1}')
    
    LAST_LINE=$(tail -n 1 "$OUTPUT_FILE")
    LAST_COUNT=$(echo "$LAST_LINE" | awk '{print $1}')

    if [[ "$FIRST_COUNT" -lt "$LAST_COUNT" ]]; then
        print_status "failed" "Lab Failed: Output not sorted in descending order by failure count."
        exit 1
    fi

    # Verify threshold: no IP with less than 3 failures should appear
    while IFS= read -r line; do
        count=$(echo "$line" | awk '{print $1}')
        if [[ "$count" -lt 3 ]]; then
            print_status "failed" "Lab Failed: IP with only $count failures found in output (threshold is 3+)."
            exit 1
        fi
    done < "$OUTPUT_FILE"

    # Verify that IP 185.220.101.33 (only 2 failures) is NOT in the output
    if grep -q "185.220.101.33" "$OUTPUT_FILE"; then
        print_status "failed" "Lab Failed: IP 185.220.101.33 should not be in output (only 2 failures)."
        exit 1
    fi

    # Verify only 401 and 403 status codes are counted
    # Check that successful requests (200 status) are not counted
    # IP 185.220.101.33 has 1 success and 2 failures, should not appear
    
    print_status "success" "Lab Passed: Correct suspicious IPs with 3+ failed login attempts detected."
}

test_suspicious_ips
exit 0