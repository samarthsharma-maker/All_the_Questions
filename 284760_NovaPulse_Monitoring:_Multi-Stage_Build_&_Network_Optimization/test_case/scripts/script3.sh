#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

IMAGE="pulse-agent:latest"
CONTAINER="pulse-agent"
NETWORK="novapulse-net"
BUILD_BASE="golang:1.21-alpine"
FINAL_BASE="alpine:3.19"

function test_config_at_correct_path() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed: Image '$IMAGE' does not exist."
        exit 1
    fi

    local result
    result=$(docker run --rm --entrypoint sh "$IMAGE" -c "test -f /app/config.yaml && echo found || echo missing")

    if [ "$result" != "found" ]; then
        print_status "failed" "Lab Failed: config.yaml not found at /app/config.yaml inside the final image. Add a COPY instruction to bring config.yaml from the build context into /app/config.yaml."
        exit 1
    fi
    print_status "success" "Lab Passed: config.yaml exists at /app/config.yaml in the final image."
}


function test_non_root_user() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed: Image '$IMAGE' does not exist."
        exit 1
    fi

    local user_exists
    user_exists=$(docker run --rm --entrypoint sh "$IMAGE" -c "grep -c '^pulse:' /etc/passwd || true")

    if [ "$user_exists" = "0" ] || [ -z "$user_exists" ]; then
        print_status "failed" "Lab Failed: User 'pulse' does not exist in the final image. Add 'RUN adduser -D pulse' (Alpine syntax) and 'USER pulse' to the final stage."
        exit 1
    fi

    local image_user
    image_user=$(docker inspect "$IMAGE" --format '{{.Config.User}}')

    if [ -z "$image_user" ] || [ "$image_user" = "root" ] || [ "$image_user" = "0" ]; then
        print_status "failed" "Lab Failed: Image USER is '${image_user:-not set}'. The Dockerfile must set 'USER pulse' in the final stage so the container does not run as root."
        exit 1
    fi

    print_status "success" "Lab Passed: Container runs as non-root user '$image_user' (user 'pulse' exists in /etc/passwd)."
}

function test_image_tag() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed: Image '$IMAGE' not found. Build with: docker build -t pulse-agent:latest /home/user/pulse-agent"
        exit 1
    fi
    print_status "success" "Lab Passed: Image '$IMAGE' exists."
}

test_config_at_correct_path
test_non_root_user
test_image_tag
print_status "success" "Lab Passed: Image built with correct tag. Proceeding to check container runtime and network configuration..."
exit 0