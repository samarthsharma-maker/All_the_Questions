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


function test_multistage_build() {
    local dockerfile="/home/user/pulse-agent/Dockerfile"

    if [ ! -f "$dockerfile" ]; then
        print_status "failed" "Lab Failed: Dockerfile not found at $dockerfile."
        exit 1
    fi

    local stage_count
    stage_count=$(grep -c "^FROM " "$dockerfile" || true)

    if [ "$stage_count" -lt 2 ]; then
        print_status "failed" "Lab Failed: Dockerfile has $stage_count FROM instruction(s). A multi-stage build requires at least 2 — one for building the binary and one for the final runtime image."
        exit 1
    fi
    print_status "success" "Lab Passed: Dockerfile uses $stage_count stages (multi-stage build confirmed)."
}


function test_build_stage_base_image() {
    local dockerfile="/home/user/pulse-agent/Dockerfile"

    local first_from
    first_from=$(grep "^FROM " "$dockerfile" | head -1 | awk '{print $2}')

    if [ "$first_from" != "$BUILD_BASE" ]; then
        print_status "failed" "Lab Failed: First FROM is '$first_from'. Build stage must use '$BUILD_BASE' exactly."
        exit 1
    fi
    print_status "success" "Lab Passed: Build stage correctly uses $BUILD_BASE."
}


function test_final_stage_base_image() {
    local dockerfile="/home/user/pulse-agent/Dockerfile"

    local last_from
    last_from=$(grep "^FROM " "$dockerfile" | tail -1 | awk '{print $2}')
    last_from=$(echo "$last_from" | awk '{print $1}')

    if [ "$last_from" != "$FINAL_BASE" ]; then
        print_status "failed" "Lab Failed: Final FROM is '$last_from'. Final stage must use '$FINAL_BASE' exactly — not golang, not scratch, not ubuntu."
        exit 1
    fi
    print_status "success" "Lab Passed: Final stage correctly uses $FINAL_BASE."
}

test_multistage_build
test_build_stage_base_image
test_final_stage_base_image
print_status "success" "Lab Passed: Dockerfile has correct multi-stage structure and base images."
exit 0



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


# ==========================================
# Test 7: config.yaml is present at /app/config.yaml in the final image
# ==========================================
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


function test_container_running() {
    local state
    state=$(docker inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null || true)

    if [ -z "$state" ]; then
        print_status "failed" "Lab Failed: No container named '$CONTAINER' found. Run: docker run -d --name pulse-agent --network novapulse-net pulse-agent:latest"
        exit 1
    fi

    if [ "$state" != "running" ]; then
        print_status "failed" "Lab Failed: Container '$CONTAINER' exists but is in state '$state'. It must be 'running'. Check logs with: docker logs pulse-agent"
        exit 1
    fi
    print_status "success" "Lab Passed: Container '$CONTAINER' is running."
}

function test_container_on_correct_network() {
    if ! docker inspect "$CONTAINER" &>/dev/null; then
        print_status "failed" "Lab Failed: Container '$CONTAINER' not found."
        exit 1
    fi

    local networks
    networks=$(docker inspect "$CONTAINER" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}')

    if ! echo "$networks" | grep -qw "$NETWORK"; then
        print_status "failed" "Lab Failed: Container '$CONTAINER' is connected to networks '${networks:-none}' but not to '$NETWORK'. Pass --network novapulse-net when running the container."
        exit 1
    fi

    print_status "success" "Lab Passed: Container '$CONTAINER' is connected to network '$NETWORK'."
}

test_container_running
test_container_on_correct_network
print_status "success" "Lab Passed: Image built with correct config file and non-root user. Proceeding to check container runtime and network configuration..."
exit 0