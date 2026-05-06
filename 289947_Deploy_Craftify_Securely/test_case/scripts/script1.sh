#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

# Copy AWS credentials to root
mkdir -p /root/.aws
cp /home/user/.aws/credentials /root/.aws/credentials 2>/dev/null || true
cp /home/user/.aws/config /root/.aws/config 2>/dev/null || true

DOCKERFILE="/home/user/craftify-eks-lab/Dockerfile"

function test_dockerfile_exists() {
    if [ ! -f "$DOCKERFILE" ]; then
        print_status "failed" "Lab Failed: Dockerfile not found at $DOCKERFILE."
        exit 1
    fi
    print_status "success" "Lab Passed: Dockerfile exists."
}

function test_no_root_user() {
    if ! grep -q "USER" "$DOCKERFILE"; then
        print_status "failed" "Lab Failed: Dockerfile has no USER instruction. Add a non-root user and switch to it before CMD."
        exit 1
    fi

    local user_val
    user_val=$(grep "^USER" "$DOCKERFILE" | tail -1 | awk '{print $2}')
    if [ "$user_val" == "root" ] || [ "$user_val" == "0" ]; then
        print_status "failed" "Lab Failed: Dockerfile switches to root user. Use a non-root user like 'node' or 'appuser'."
        exit 1
    fi
    print_status "success" "Lab Passed: Dockerfile runs as non-root user '$user_val'."
}

function test_pinned_base_image() {
    local from_line
    from_line=$(grep "^FROM" "$DOCKERFILE" | head -1)

    if echo "$from_line" | grep -q ":latest"; then
        print_status "failed" "Lab Failed: Base image uses ':latest' tag. Pin to a specific version like 'node:18-alpine'."
        exit 1
    fi
    print_status "success" "Lab Passed: Base image is pinned to a specific version."
}

function test_no_unnecessary_packages() {
    for pkg in telnet vim "net-tools"; do
        if grep -q "$pkg" "$DOCKERFILE"; then
            print_status "failed" "Lab Failed: Dockerfile still installs '$pkg' which is not needed in production. Remove unnecessary packages."
            exit 1
        fi
    done
    print_status "success" "Lab Passed: No unnecessary packages found in Dockerfile."
}

function test_healthcheck_exists() {
    if ! grep -q "HEALTHCHECK" "$DOCKERFILE"; then
        print_status "failed" "Lab Failed: No HEALTHCHECK instruction in Dockerfile. Add a HEALTHCHECK that hits /health on port 3000."
        exit 1
    fi
    print_status "success" "Lab Passed: HEALTHCHECK instruction is present."
}

test_dockerfile_exists
test_no_root_user
test_pinned_base_image
test_no_unnecessary_packages
test_healthcheck_exists

print_status "success" "Lab Passed: Dockerfile is correctly hardened with non-root user, pinned image, no unnecessary packages, and a HEALTHCHECK."
exit 0