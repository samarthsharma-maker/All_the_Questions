#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

IMAGE="pulse-agent:v2"
CONTAINER="pulse-agent-staging"
NETWORK="novapulse-net"


function test_app_env_default() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed [A3]: Image '$IMAGE' not found."
        exit 1
    fi

    local val
    val=$(docker inspect "$IMAGE" --format '{{json .Config.Env}}' | grep -o '"APP_ENV=[^"]*"' | awk -F= '{print $2}' | tr -d '"')

    if [ -z "$val" ]; then
        print_status "failed" "Lab Failed [A3]: APP_ENV not found in image ENV. Add 'ENV APP_ENV=production' to the final stage."
        exit 1
    fi
    if [ "$val" != "production" ]; then
        print_status "failed" "Lab Failed [A3]: APP_ENV default is '$val' — must be 'production'."
        exit 1
    fi
    print_status "success" "Lab Passed [A3]: APP_ENV defaults to 'production' in the image."
}


function test_log_level_default() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed [A3]: Image '$IMAGE' not found."
        exit 1
    fi

    local val
    val=$(docker inspect "$IMAGE" --format '{{json .Config.Env}}' | grep -o '"LOG_LEVEL=[^"]*"' | awk -F= '{print $2}' | tr -d '"')

    if [ -z "$val" ]; then
        print_status "failed" "Lab Failed [A3]: LOG_LEVEL not found in image ENV. Add 'ENV LOG_LEVEL=info' to the final stage."
        exit 1
    fi
    if [ "$val" != "info" ]; then
        print_status "failed" "Lab Failed [A3]: LOG_LEVEL default is '$val' — must be 'info'."
        exit 1
    fi
    print_status "success" "Lab Passed [A3]: LOG_LEVEL defaults to 'info' in the image."
}


function test_build_version_not_in_env() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed [B1]: Image '$IMAGE' not found."
        exit 1
    fi

    local leaked
    leaked=$(docker inspect "$IMAGE" --format '{{json .Config.Env}}' | grep -o '"BUILD_VERSION=[^"]*"' || true)

    if [ -n "$leaked" ]; then
        print_status "failed" "Lab Failed [B1]: BUILD_VERSION is present as an ENV in the final image ('$leaked'). Remove 'ENV BUILD_VERSION=\${BUILD_VERSION}' — keep BUILD_VERSION as ARG only so it does not persist in the image or any container spawned from it."
        exit 1
    fi

    print_status "success" "Lab Passed [B1]: BUILD_VERSION is not in the final image ENV."
}

test_app_env_default
test_log_level_default
test_build_version_not_in_env
print_status "success" "Lab Passed: Image has correct ENV configuration. Proceeding to check secrets exclusion and container runtime configuration..."
exit 0
