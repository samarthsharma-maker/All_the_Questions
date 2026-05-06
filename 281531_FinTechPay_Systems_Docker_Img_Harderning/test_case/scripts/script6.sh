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

function test_slim_or_alpine_base() {
    if [ ! -f "$DOCKERFILE" ]; then
        print_status "failed" "Dockerfile not found at $DOCKERFILE"
        exit 1
    fi

    local final_from
    final_from=$(grep -v '^\s*#' "$DOCKERFILE" | grep -i '^FROM' | tail -n 1)
    
    if [ -z "$final_from" ]; then
        print_status "failed" "No FROM statement found in Dockerfile"
        exit 1
    fi
    
    if echo "$final_from" | grep -qE '(slim|alpine)'; then
        local variant
        if echo "$final_from" | grep -q 'alpine'; then
            variant="alpine"
        else
            variant="slim"
        fi
        print_status "success" "Final stage uses optimized base image ($variant)"
    else
        print_status "failed" "Final stage should use slim or alpine base image for size optimization. Found: $final_from"
        exit 1
    fi
}

test_slim_or_alpine_base
exit 0