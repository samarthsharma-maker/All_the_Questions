#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

BASE_DIR="/home/user/"
FILE_PATH="${BASE_DIR}/python-docker-app/"
DOCKERFILE="$FILE_PATH/Dockerfile"

function cleanup() { :; }
trap cleanup EXIT


function test_multistage_build() {
    local from_count
    from_count=$(grep -i '^FROM' "$DOCKERFILE" | wc -l)

    if [ "$from_count" -lt 2 ]; then
        print_status "failed" "Dockerfile is not a multi-stage build (found $from_count FROM statements)"
        exit 1
    fi

    print_status "success" "Dockerfile uses multi-stage build"
}

test_multistage_build
exit 0