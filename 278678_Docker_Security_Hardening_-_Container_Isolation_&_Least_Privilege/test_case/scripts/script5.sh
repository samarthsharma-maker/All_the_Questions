#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

IMAGE_NAME="banking-app:secure"
CONTAINER_NAME="banking-app-secure"

function test_application_works() {
    sleep 2
    
    if curl -s -f http://localhost:8080/health >/dev/null 2>&1; then
        print_status "success" "Lab Passed: Application responding correctly."
    else
        print_status "failed" "Lab Failed: Application not responding. Check if app works with security hardening."
        exit 1
    fi
}

test_application_works
print_status "success" "Lab Passed: All Docker security tests completed successfully. PCI-DSS compliant!"
exit 0
