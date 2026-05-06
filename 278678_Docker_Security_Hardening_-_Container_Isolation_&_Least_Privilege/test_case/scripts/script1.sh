#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

IMAGE_NAME="banking-app:secure"
CONTAINER_NAME="banking-app-secure"

function test_dockerfile_has_user() {
    if [ ! -f "Dockerfile" ]; then
        print_status "failed" "Lab Failed: Dockerfile not found in current directory."
        exit 1
    fi
    
    if ! grep -q "^USER " Dockerfile; then
        print_status "failed" "Lab Failed: Dockerfile missing USER directive."
        exit 1
    fi
    
    local user_line
    user_line=$(grep "^USER " Dockerfile | tail -1 | awk '{print $2}')
    
    if [ "$user_line" == "root" ] || [ "$user_line" == "0" ]; then
        print_status "failed" "Lab Failed: USER directive set to root. Must be non-root user."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Dockerfile has USER directive ($user_line)."
}

function test_no_secrets_in_dockerfile() {
    if grep -iE "password|secret|api_key|apikey|token" Dockerfile | grep -v "^#" | grep -E "ENV|ARG" >/dev/null 2>&1; then
        print_status "failed" "Lab Failed: Dockerfile contains hardcoded secrets (ENV/ARG with password/secret/key)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: No hardcoded secrets found in Dockerfile."
}

test_dockerfile_has_user
test_no_secrets_in_dockerfile



exit 0