#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

IMAGE="fintechpay-python-app"
CONTAINER="fintechpay-test-run"

function cleanup() { docker rm -f $(docker ps -q) >/dev/null 2>&1 || true; }

function test_container_runs() {
    cleanup

    if ! docker run -d --name "$CONTAINER" -p 8080:8080 "$IMAGE" >/dev/null; then
        print_status "failed" "Container failed to start"
        exit 1
    fi

    sleep 3

    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        print_status "failed" "Container is not running"
        exit 1
    fi

    print_status "success" "Container runs successfully"
}

test_container_runs
exit 0