#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error handle_script_error
trap - ERR

NETWORK="clearbank-net"

function test_network_exists() {
    if ! docker network inspect "$NETWORK" &> /dev/null; then
        print_status "failed" "Docker network '$NETWORK' does not exist."
        exit 1
    fi
    print_status "success" "Network '$NETWORK' exists."
}

function test_network_driver() {
    local driver
    driver=$(docker network inspect "$NETWORK" --format '{{.Driver}}')
    if [ "$driver" != "bridge" ]; then
        print_status "failed" "Network '$NETWORK' must be bridge (found: $driver)."
        exit 1
    fi
    print_status "success" "Network '$NETWORK' is bridge."
}

# Run tests
test_network_exists
test_network_driver
print_status "success" "Network '$NETWORK' exists and is a bridge network."
exit 0
