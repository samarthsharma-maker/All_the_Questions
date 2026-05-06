#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

function load_config() {
    local config="/home/user/craftify-deploy-lab/lab-config.txt"
    if [ ! -f "$config" ]; then
        print_status "failed" "Lab Failed: Lab config not found. Run the setup script first."
        exit 1
    fi
    source "$config"
}

function test_http_returns_200() {
    load_config

    local http_status
    http_status=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://${INSTANCE_IP}/index.html" \
        --connect-timeout 10 2>/dev/null || echo "0")

    if [ "$http_status" != "200" ]; then
        print_status "failed" "Lab Failed: HTTP request to instance returned $http_status instead of 200. Ensure the deployment succeeded and httpd is running on the instance."
        exit 1
    fi
    print_status "success" "Lab Passed: Instance is serving HTTP 200 on port 80."
}

function test_response_contains_craftify() {
    load_config

    local body
    body=$(curl -s "http://${INSTANCE_IP}/index.html" \
        --connect-timeout 10 2>/dev/null || echo "")

    if ! echo "$body" | grep -q "Craftify Learning Platform"; then
        print_status "failed" "Lab Failed: Response body does not contain 'Craftify Learning Platform'. The correct artifact may not have been deployed."
        exit 1
    fi
    print_status "success" "Lab Passed: Response contains 'Craftify Learning Platform'."
}

function test_response_contains_version() {
    load_config

    local body
    body=$(curl -s "http://${INSTANCE_IP}/index.html" \
        --connect-timeout 10 2>/dev/null || echo "")

    if ! echo "$body" | grep -q "2.1.3"; then
        print_status "failed" "Lab Failed: Response body does not contain version '2.1.3'. Ensure the correct artifact was deployed."
        exit 1
    fi
    print_status "success" "Lab Passed: Response confirms version 2.1.3 is deployed."
}

test_http_returns_200
test_response_contains_craftify
test_response_contains_version

print_status "success" "Lab Passed: Craftify version 2.1.3 is successfully deployed and accessible on port 80."
exit 0