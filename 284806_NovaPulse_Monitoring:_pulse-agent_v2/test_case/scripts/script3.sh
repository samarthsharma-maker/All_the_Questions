#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

IMAGE="pulse-agent:v2"
CONTAINER="pulse-agent-staging"
NETWORK="novapulse-net"

function test_tests_excluded() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed [B2]: Image '$IMAGE' not found."
        exit 1
    fi

    local found
    found=$(docker run --rm --entrypoint sh "$IMAGE" -c "find / -name 'main_test.go' 2>/dev/null | head -1 || true")

    if [ -n "$found" ]; then
        print_status "failed" "Lab Failed [B2]: tests/main_test.go found in the image at '$found'. Add 'tests/' to .dockerignore."
        exit 1
    fi

    print_status "success" "Lab Passed [B2]: tests/ is not present in the final image."
}

function test_dotenv_excluded() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed [B2]: Image '$IMAGE' not found."
        exit 1
    fi

    local found
    found=$(docker run --rm --entrypoint sh "$IMAGE" -c "find / -name '.env' 2>/dev/null | head -1 || true")

    if [ -n "$found" ]; then
        print_status "failed" "Lab Failed [B2]: .env file found in the image at '$found'. Add '.env' to .dockerignore — this file contains local dev secrets."
        exit 1
    fi

    print_status "success" "Lab Passed [B2]: .env is not present in the final image."
}

function test_image_tag() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed: Image '$IMAGE' not found. Build with: docker build --build-arg BUILD_VERSION=2.0.0 -t pulse-agent:v2 /home/user/pulse-agent"
        exit 1
    fi
    print_status "success" "Lab Passed: Image '$IMAGE' exists."
}

test_tests_excluded
test_dotenv_excluded
test_image_tag
print_status "success" "Lab Passed: Image excludes secrets and tests. Proceeding to check container runtime configuration and network setup..."
exit 0
