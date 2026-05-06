#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

CONTAINER="fintechpay-test-run"

function cleanup() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    fi
}

function test_app_responds() {
    sleep 2

    if ! curl -s http://localhost:8080 >/dev/null; then
        print_status "failed" "Application is not responding on port 8080"
        exit 1
    fi

    print_status "success" "Application responds on port 8080"
}

test_app_responds
exit 0