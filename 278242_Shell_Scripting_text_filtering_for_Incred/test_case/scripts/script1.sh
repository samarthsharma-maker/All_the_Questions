#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

BASE_DIR="/home/user"

SCRIPT="${BASE_DIR}/unique_ips.sh"
OUTPUT_FILE="${BASE_DIR}/unique_ip.txt"

function test_script_exist() {
    if [[ ! -f "$SCRIPT" ]]; then
        print_status "failed" "Lab Failed: unique_ips.sh script not found."
        exit 1
    fi
}

function test_output_file() {
    if [[ ! -f "$OUTPUT_FILE" ]]; then
        print_status "failed" "Lab Failed: Output file unique_ip.txt not created."
        exit 1
    fi
}


test_script_exist
test_output_file
print_status "success" "Lab Passed: Script executed and output file created successfully."
exit 0
