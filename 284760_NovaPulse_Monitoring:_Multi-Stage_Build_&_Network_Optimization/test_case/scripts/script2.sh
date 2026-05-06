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


function test_no_go_toolchain_in_final_image() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed: Image '$IMAGE' does not exist. Build the image first."
        exit 1
    fi

    local go_path
    go_path=$(docker run --rm --entrypoint sh "$IMAGE" -c "which go 2>/dev/null || true")

    if [ -n "$go_path" ]; then
        print_status "failed" "Lab Failed: Go toolchain found at '$go_path' inside the final image. The final stage must be a clean '$FINAL_BASE' base — copy only the compiled binary, not the entire build stage."
        exit 1
    fi
    print_status "success" "Lab Passed: Go toolchain is not present in the final image."
}

function test_cgo_disabled_in_dockerfile() {
    local dockerfile="/home/user/pulse-agent/Dockerfile"

    if ! grep -q "CGO_ENABLED=0" "$dockerfile"; then
        print_status "failed" "Lab Failed: Dockerfile does not set CGO_ENABLED=0 in the build command. Without this, the binary may link against glibc and fail to start on Alpine (which uses musl)."
        exit 1
    fi

    if ! grep -q "GOOS=linux" "$dockerfile"; then
        print_status "failed" "Lab Failed: Dockerfile does not set GOOS=linux in the build command. This is required for a portable static Linux binary."
        exit 1
    fi
    print_status "success" "Lab Passed: Dockerfile sets CGO_ENABLED=0 and GOOS=linux for the build."
}

function test_binary_at_correct_path() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed: Image '$IMAGE' does not exist."
        exit 1
    fi

    local result
    result=$(docker run --rm --entrypoint sh "$IMAGE" -c "test -f /app/pulse-agent && echo found || echo missing")

    if [ "$result" != "found" ]; then
        print_status "failed" "Lab Failed: Binary not found at /app/pulse-agent inside the final image. Ensure the COPY --from instruction places the binary at /app/pulse-agent."
        exit 1
    fi
    print_status "success" "Lab Passed: Binary exists at /app/pulse-agent in the final image."
}

test_no_go_toolchain_in_final_image
test_cgo_disabled_in_dockerfile
test_binary_at_correct_path
print_status "success" "Lab Passed: Final image has no Go toolchain, CGO is disabled, and binary is at correct path. Proceeding to check config file, user, image tag, and runtime container/network..."
exit 0