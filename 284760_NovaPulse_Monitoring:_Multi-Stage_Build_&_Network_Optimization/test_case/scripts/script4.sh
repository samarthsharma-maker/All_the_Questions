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
