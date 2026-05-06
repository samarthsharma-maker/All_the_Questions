#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

IMAGE="fintechpay-python-app"

function cleanup() { :; }

trap cleanup EXIT

function test_image_exists() {
    if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
        print_status "failed" "Docker image '$IMAGE' does not exist"
        exit 1
    fi

    print_status "success" "Docker image '$IMAGE' exists"
}

test_image_exists
exit 0