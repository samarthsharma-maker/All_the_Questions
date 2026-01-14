#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

BASE_DIR="/home/user"

SCRIPT="${BASE_DIR}/count_requests.sh"
OUTPUT_FILE="${BASE_DIR}/request_count.txt"

function test_script_exist() {
    if [[ ! -f "$SCRIPT" ]]; then
        print_status "failed" "Lab Failed: count_requests.sh script not found."
        exit 1
    fi
}

function test_output_file() {
    if [[ ! -f "$OUTPUT_FILE" ]]; then
        print_status "failed" "Lab Failed: Output file request_count.txt not created."
        exit 1
    fi
}


test_script_exist
test_output_file
print_status "success" "Lab Passed: Script executed and output file created successfully."
exit 0