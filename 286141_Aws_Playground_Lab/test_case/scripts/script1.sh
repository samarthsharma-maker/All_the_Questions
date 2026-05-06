#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

print_status "success" "Lab Passed: Hope you learned something"
exit 0
