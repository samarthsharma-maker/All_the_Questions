#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error handle_script_error
trap - ERR


function test_health_endpoint() {
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)

    if [ "$code" != "200" ]; then
        print_status "failed" "/health should return 200 (got $code)."
        exit 1
    fi

    print_status "success" "/health endpoint returned 200."
}


function test_ping_db_endpoint() {
    local attempts=5
    local code="000"

    for _ in $(seq 1 $attempts); do
        code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ping-db)
        [ "$code" = "200" ] && break
        sleep 3
    done

    if [ "$code" != "200" ]; then
        print_status "failed" "/ping-db did not return 200 — DB unreachable."
        exit 1
    fi

    print_status "success" "/ping-db endpoint returned 200."
}

# Run tests
test_health_endpoint
test_ping_db_endpoint

print_status "success" "All API endpoint tests passed."
exit 0
