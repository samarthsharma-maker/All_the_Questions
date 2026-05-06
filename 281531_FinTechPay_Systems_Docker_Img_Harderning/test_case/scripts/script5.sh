#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

CONTAINER="fintechpay-test-run"

function cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

function test_non_root_user() {
    local uid
    uid=$(docker exec "$CONTAINER" id -u 2>/dev/null)

    if [ "$uid" -eq 0 ]; then
        print_status "failed" "Container is running as root (UID 0)"
        exit 1
    fi

    print_status "success" "Container runs as non-root user (UID $uid)"
}

test_non_root_user

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
exit 0