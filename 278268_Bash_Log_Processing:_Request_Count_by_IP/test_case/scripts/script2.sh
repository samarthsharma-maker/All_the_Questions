#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

# Expected output: count followed by IP, sorted by count descending
EXPECTED_OUTPUT=(
    "2 192.168.1.100"
    "2 185.220.101.33"
    "1 203.0.113.200"
    "1 123.45.67.89"
    "1 98.76.54.32"
    "1 45.33.21.156"
)

BASE_DIR="/home/user"
SCRIPT="${BASE_DIR}/count_requests.sh"
OUTPUT_FILE="${BASE_DIR}/request_count.txt"

function test_request_count_output() {

    chmod +x "$SCRIPT"
    "$SCRIPT"
    
    # Check if output file has correct number of lines
    FILE_LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
    EXPECTED_COUNT=${#EXPECTED_OUTPUT[@]}

    if [[ "$FILE_LINE_COUNT" -ne "$EXPECTED_COUNT" ]]; then
        print_status "failed" "Lab Failed: request_count.txt contains $FILE_LINE_COUNT lines, expected $EXPECTED_COUNT."
        exit 1
    fi

    # Check if each expected line exists in the output
    for expected_line in "${EXPECTED_OUTPUT[@]}"; do
        if ! grep -qF "$expected_line" "$OUTPUT_FILE"; then
            print_status "failed" "Lab Failed: Expected line '$expected_line' missing from request_count.txt."
            exit 1
        fi
    done

    # Verify sorting order (descending by count)
    FIRST_LINE=$(head -n 1 "$OUTPUT_FILE")
    FIRST_COUNT=$(echo "$FIRST_LINE" | awk '{print $1}')
    
    LAST_LINE=$(tail -n 1 "$OUTPUT_FILE")
    LAST_COUNT=$(echo "$LAST_LINE" | awk '{print $1}')

    if [[ "$FIRST_COUNT" -lt "$LAST_COUNT" ]]; then
        print_status "failed" "Lab Failed: Output not sorted in descending order by count."
        exit 1
    fi

    # Verify that only GET requests are counted
    # Check if any POST IPs appear in output (they shouldn't)
    POST_IPS=("98.76.54.32" "185.220.101.33" "45.33.21.156")
    
    for post_ip in "${POST_IPS[@]}"; do
        # These IPs also made GET requests, so check the counts are correct
        if [[ "$post_ip" == "98.76.54.32" ]]; then
            # This IP made 1 GET and 3 POST requests - should show count of 1
            if grep -q "3 $post_ip" "$OUTPUT_FILE"; then
                print_status "failed" "Lab Failed: Incorrectly counted POST requests for $post_ip."
                exit 1
            fi
        fi
    done

    print_status "success" "Lab Passed: Correct request counts for GET requests detected."
}

test_request_count_output
exit 0