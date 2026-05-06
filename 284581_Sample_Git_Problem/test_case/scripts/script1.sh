#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

# Write your test logic here

function check_repo_status() {
    if git diff | awk '{print $3}' == "modified:" && git diff | awk '{print $4}' == "setup/scripts/setup_script.sh"; then
        print_status "success" "Test Passed: setup/scripts/setup_script.sh is modified as expected."
    else
        print_status "failed" "Test Failed: setup/scripts/setup_script.sh is not modified as expected."
        exit 1
    fi
}


check_repo_status
print_status "success" "Lab Passed: Git repository is in the expected state with the required
exit 0
