#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error handle_script_error
trap - ERR

NETWORK="clearbank-net"
DB_CONTAINER="db"

function test_db_container_running() {
    local state

    docker inspect "$DB_CONTAINER" &> /dev/null || {
        print_status "failed" "Container '$DB_CONTAINER' does not exist."
        exit 1
    }

    state=$(docker inspect "$DB_CONTAINER" --format '{{.State.Status}}')
    if [ "$state" != "running" ]; then
        print_status "failed" "Container '$DB_CONTAINER' is not running (state: $state)."
        exit 1
    fi

    print_status "success" "DB container exists and is running."
}

function test_db_on_network() {
    local networks
    networks=$(docker inspect "$DB_CONTAINER" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}')

    if ! echo "$networks" | grep -qw "$NETWORK"; then
        print_status "failed" "DB container not connected to '$NETWORK'."
        exit 1
    fi

    print_status "success" "DB container connected to '$NETWORK'."
}

function test_db_env_vars() {
    local envs
    envs=$(docker inspect "$DB_CONTAINER" --format '{{json .Config.Env}}')

    echo "$envs" | grep -q "POSTGRES_USER=clearbank" || { print_status "failed" "POSTGRES_USER incorrect."; exit 1; }
    echo "$envs" | grep -q "POSTGRES_PASSWORD=secret123" || { print_status "failed" "POSTGRES_PASSWORD incorrect."; exit 1; }
    echo "$envs" | grep -q "POSTGRES_DB=accounts" || { print_status "failed" "POSTGRES_DB incorrect."; exit 1; }

    print_status "success" "DB env vars are correct."
}

function test_db_port_not_exposed() {
    local ports
    ports=$(docker inspect "$DB_CONTAINER" --format '{{json .NetworkSettings.Ports}}')

    if echo "$ports" | grep -q '"5432/tcp":\['; then
        print_status "failed" "DB port 5432 must not be exposed."
        exit 1
    fi

    print_status "success" "DB port is not exposed."
}

# Run tests
test_db_container_running
test_db_on_network
test_db_env_vars
test_db_port_not_exposed

print_status "success" "All DB container tests passed."
exit 0
