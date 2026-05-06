#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

IMAGE="pulse-agent:v2"
CONTAINER="pulse-agent-staging"
NETWORK="novapulse-net"


function test_entrypoint_exec_form() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed [A1]: Image '$IMAGE' not found. Build with: docker build --build-arg BUILD_VERSION=2.0.0 -t pulse-agent:v2 /home/user/pulse-agent"
        exit 1
    fi

    local entrypoint
    entrypoint=$(docker inspect "$IMAGE" --format '{{json .Config.Entrypoint}}')

    if ! echo "$entrypoint" | grep -q '^\['; then
        print_status "failed" "Lab Failed [A1]: ENTRYPOINT is not exec form (got: '$entrypoint'). Shell form makes sh PID 1 — the Go process never receives SIGTERM. Use: ENTRYPOINT [\"/app/pulse-agent\"]"
        exit 1
    fi

    if ! echo "$entrypoint" | grep -q '^\["/app/pulse-agent"'; then
        print_status "failed" "Lab Failed [A1]: ENTRYPOINT exec form does not reference /app/pulse-agent (got: '$entrypoint')."
        exit 1
    fi
    print_status "success" "Lab Passed [A1]: ENTRYPOINT exec form — $entrypoint."
}

function test_healthcheck_exec_form() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed [A2]: Image '$IMAGE' not found."
        exit 1
    fi

    local hc_test
    hc_test=$(docker inspect "$IMAGE" --format '{{json .Config.Healthcheck.Test}}')

    if [ -z "$hc_test" ] || [ "$hc_test" = "null" ]; then
        print_status "failed" "Lab Failed [A2]: No HEALTHCHECK instruction in the image. Add: HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD [\"/app/healthcheck\"]"
        exit 1
    fi

    if echo "$hc_test" | grep -q '"CMD-SHELL"'; then
        print_status "failed" "Lab Failed [A2]: HEALTHCHECK is shell form (CMD-SHELL). Use exec form: HEALTHCHECK CMD [\"/app/healthcheck\"] — no sh spawned per probe."
        exit 1
    fi

    if ! echo "$hc_test" | grep -q '"CMD"'; then
        print_status "failed" "Lab Failed [A2]: HEALTHCHECK does not use CMD exec form (got: '$hc_test')."
        exit 1
    fi

    if ! echo "$hc_test" | grep -q "/app/healthcheck"; then
        print_status "failed" "Lab Failed [A2]: HEALTHCHECK does not reference /app/healthcheck (got: '$hc_test')."
        exit 1
    fi
    print_status "success" "Lab Passed [A2]: HEALTHCHECK exec form — $hc_test."
}

function test_healthcheck_parameters() {
    if ! docker image inspect "$IMAGE" &>/dev/null; then
        print_status "failed" "Lab Failed [A2]: Image '$IMAGE' not found."
        exit 1
    fi

    local interval timeout retries
    interval=$(docker inspect "$IMAGE" --format '{{.Config.Healthcheck.Interval}}')
    timeout=$(docker inspect "$IMAGE"  --format '{{.Config.Healthcheck.Timeout}}')
    retries=$(docker inspect "$IMAGE"  --format '{{.Config.Healthcheck.Retries}}')

    if [ "$interval" != "30s" ]; then
        print_status "failed" "Lab Failed [A2]: HEALTHCHECK --interval is ${interval} (expected 30000000000 = 30s)."
        exit 1
    fi
    if [ "$timeout" != "5s" ]; then
        print_status "failed" "Lab Failed [A2]: HEALTHCHECK --timeout is ${timeout} (expected 5000000000 = 5s)."
        exit 1
    fi
    if [ "$retries" != "3" ]; then
        print_status "failed" "Lab Failed [A2]: HEALTHCHECK --retries is ${retries} (expected 3)."
        exit 1
    fi
    print_status "success" "Lab Passed [A2]: HEALTHCHECK parameters — interval=30s, timeout=5s, retries=3."
}


test_entrypoint_exec_form
test_healthcheck_exec_form
test_healthcheck_parameters
print_status "success" "Lab Passed: Image has correct ENTRYPOINT and HEALTHCHECK configuration. Proceeding to check ENV variables, secrets exclusion, and container runtime configuration..."
exit 0

