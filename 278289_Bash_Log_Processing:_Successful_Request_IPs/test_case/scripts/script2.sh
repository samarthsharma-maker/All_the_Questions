#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

# Expected unique IPs from successful requests (status 200)
EXPECTED_IPS=(
    "123.45.67.89"
    "185.220.101.33"
    "192.168.1.100"
    "203.0.113.200"
    "45.33.21.156"
    "98.76.54.32"
)

BASE_DIR="/home/user"
SCRIPT="${BASE_DIR}/successful_ips.sh"
OUTPUT_FILE="${BASE_DIR}/unique_success_ips.txt"

function test_unique_success_ips() {

    chmod +x "$SCRIPT"
    "$SCRIPT"
    
    # Check if output file has correct number of lines
    FILE_LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
    EXPECTED_COUNT=${#EXPECTED_IPS[@]}

    if [[ "$FILE_LINE_COUNT" -ne "$EXPECTED_COUNT" ]]; then
        print_status "failed" "Lab Failed: unique_success_ips.txt contains $FILE_LINE_COUNT lines, expected $EXPECTED_COUNT."
        exit 1
    fi

    # Check if each expected IP exists in the output
    for ip in "${EXPECTED_IPS[@]}"; do
        if ! grep -qx "$ip" "$OUTPUT_FILE"; then
            print_status "failed" "Lab Failed: Expected IP '$ip' missing from unique_success_ips.txt."
            exit 1
        fi
    done

    # Verify no duplicate IPs
    DUPLICATE_COUNT=$(sort "$OUTPUT_FILE" | uniq -d | wc -l)
    if [[ "$DUPLICATE_COUNT" -gt 0 ]]; then
        print_status "failed" "Lab Failed: Duplicate IPs found in output file."
        exit 1
    fi

    # Verify alphabetical sorting
    SORTED_OUTPUT=$(sort "$OUTPUT_FILE")
    ACTUAL_OUTPUT=$(cat "$OUTPUT_FILE")
    if [[ "$SORTED_OUTPUT" != "$ACTUAL_OUTPUT" ]]; then
        print_status "failed" "Lab Failed: Output is not sorted alphabetically."
        exit 1
    fi

    # Verify that only status 200 IPs are included (check that failed request IPs are NOT in output from lines with 401/403)
    # These IPs should NOT appear if they only had failed requests
    # But in our test data, all IPs with failures also have successes, so this check is informational
    
    print_status "success" "Lab Passed: Correct unique IPs from successful requests (status 200) detected."
}

test_unique_success_ips
exit 0