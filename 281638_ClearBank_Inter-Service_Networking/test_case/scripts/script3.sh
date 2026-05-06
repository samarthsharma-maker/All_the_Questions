#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error handle_script_error
trap - ERR

API_IMAGE="clearbank-api"
API_CONTAINER="api"


function test_api_image_exists() {
    if ! docker image inspect "$API_IMAGE" &> /dev/null; then
        print_status "failed" "Image '$API_IMAGE' does not exist."
        exit 1
    fi
    print_status "success" "API image exists."
}

function test_api_container_running() {
    local state

    docker inspect "$API_CONTAINER" &> /dev/null || {
        print_status "failed" "Container '$API_CONTAINER' does not exist."
        exit 1
    }

    state=$(docker inspect "$API_CONTAINER" --format '{{.State.Status}}')
    if [ "$state" != "running" ]; then
        print_status "failed" "API container not running (state: $state)."
        exit 1
    fi

    print_status "success" "API container is running."
}

# Run tests
test_api_image_exists
test_api_container_running

print_status "success" "All API container tests passed."
exit 0
