#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

IMAGE_NAME="banking-app:secure"
CONTAINER_NAME="banking-app-secure"

function test_image_exists() {
    if ! docker images "$IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_NAME"; then
        print_status "failed" "Lab Failed: Docker image '$IMAGE_NAME' not found. Build the image first."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Docker image '$IMAGE_NAME' exists."
}

function test_container_nonroot_user() {
    if ! docker ps --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        docker run -d --name "$CONTAINER_NAME" --memory="512m" --cpus="0.5" --cap-drop=ALL --read-only --tmpfs /tmp -p 8080:8080 "$IMAGE_NAME" >/dev/null 2>&1 || true
        sleep 3
    fi
    
    if ! docker ps --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
        print_status "failed" "Lab Failed: Container not running. Check if image works correctly."
        exit 1
    fi
    
    local uid
    uid=$(docker exec "$CONTAINER_NAME" id -u 2>/dev/null)
    
    if [ -z "$uid" ]; then
        print_status "failed" "Lab Failed: Could not check user ID in container."
        exit 1
    fi
    
    if [ "$uid" -eq 0 ] 2>/dev/null; then
        print_status "failed" "Lab Failed: Container is running as root (UID 0). Must run as non-root."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Container running as non-root user (UID: $uid)."
}

test_image_exists
test_container_nonroot_user

exit 0
