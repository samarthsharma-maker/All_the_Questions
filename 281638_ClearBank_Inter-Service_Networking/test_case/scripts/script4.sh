#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error handle_script_error
trap - ERR

NETWORK="clearbank-net"
API_CONTAINER="api"
DB_CONTAINER="db"


function test_api_on_network() {
    local networks
    networks=$(docker inspect "$API_CONTAINER" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}')

    if ! echo "$networks" | grep -qw "$NETWORK"; then
        print_status "failed" "API container not connected to '$NETWORK'."
        exit 1
    fi

    print_status "success" "API container connected to '$NETWORK'."
}


function test_api_env_vars() {
    local envs
    envs=$(docker inspect "$API_CONTAINER" --format '{{json .Config.Env}}')

    echo "$envs" | grep -q "DB_HOST=db" || { print_status "failed" "DB_HOST must be 'db'."; exit 1; }
    echo "$envs" | grep -q "DB_PORT=5432" || { print_status "failed" "DB_PORT must be '5432'."; exit 1; }
    echo "$envs" | grep -q "DB_USER=clearbank" || { print_status "failed" "DB_USER must be 'clearbank'."; exit 1; }
    echo "$envs" | grep -q "DB_PASSWORD=secret123" || { print_status "failed" "DB_PASSWORD must be 'secret123'."; exit 1; }
    echo "$envs" | grep -q "DB_NAME=accounts" || { print_status "failed" "DB_NAME must be 'accounts'."; exit 1; }

    print_status "success" "API env vars are correct."
}


function test_api_port_exposed() {
    local host_port

    # Docker binds on both 0.0.0.0 and :: by default, so the Ports JSON
    # contains two HostPort entries for one -p flag.  head -1 picks only
    # the first match — avoids the "80808080" concatenation problem.
    # Works even when python3 is not available.
    host_port=$(docker inspect "$API_CONTAINER" --format '{{json .NetworkSettings.Ports}}' \
        | grep -o '"HostPort":"[0-9]*"' | head -1 | grep -o '[0-9]*')

    if [ "$host_port" != "8080" ]; then
        print_status "failed" "Lab Failed: Container '$API_CONTAINER' should expose port 8080 on the host (found host port: '$host_port')."
        exit 1
    fi

    print_status "success" "Lab Passed: API container exposes port 8080 on the host."
}


function test_shared_network() {
    local api_nets db_nets

    api_nets=$(docker inspect "$API_CONTAINER" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}')
    db_nets=$(docker inspect "$DB_CONTAINER" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}')

    if ! echo "$api_nets" | grep -qw "$NETWORK" || ! echo "$db_nets" | grep -qw "$NETWORK"; then
        print_status "failed" "API and DB must share network '$NETWORK'."
        exit 1
    fi

    print_status "success" "API and DB share the same network."
}

# Run tests
test_api_on_network
test_api_env_vars
test_api_port_exposed
test_shared_network

print_status "success" "All API container tests passed."
exit 0
