#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

IMAGE_NAME="memory-hog"
CONTAINER_NAME="safe-app"

if [ ! -f "Dockerfile.memory" ] && [ -f "/home/user/datacrunch-solution/Dockerfile.memory" ]; then
    cd "/home/user/datacrunch-solution" || exit 1
fi

function test_image_exists() {
    if ! docker images "$IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_NAME"; then
        print_status "failed" "Lab Failed: Image '$IMAGE_NAME' not found."
        exit 1
    fi
    print_status "success" "Lab Passed: Image exists."
}

function start_container_with_limits() {
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    sleep 1
    docker run -d --name "$CONTAINER_NAME" --memory="512m" --memory-reservation="256m" --cpus=0.5 "$IMAGE_NAME" >/dev/null 2>&1
    sleep 2
    
    if ! docker ps --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        if docker ps -a --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
            print_status "success" "Lab Passed: Container started with limits (may have OOMKilled, that's expected)."
            return
        fi
        print_status "failed" "Lab Failed: Container not found."
        exit 1
    fi
    print_status "success" "Lab Passed: Container started with limits."
}

test_image_exists
start_container_with_limits

exit 0