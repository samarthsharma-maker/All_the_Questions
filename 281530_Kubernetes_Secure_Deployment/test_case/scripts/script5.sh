#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="secure-deploy-prod"
DEPLOYMENT="microservice-app"

function test_readiness_probe_exists() {
    probe=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}')

    if [ "$probe" != "/" ]; then
        print_status "failed" "Readiness probe not configured correctly."
        exit 1
    fi
    print_status "success" "Readiness probe configured."
}

function test_resource_requests_and_limits_exist() {
    req_cpu=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
    lim_mem=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}')

    if [ -z "$req_cpu" ] || [ -z "$lim_mem" ]; then
        print_status "failed" "Resource requests or limits missing."
        exit 1
    fi
    print_status "success" "Resource requests and limits configured."
}

function test_replicas_not_modified() {
    replicas=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
    if [ "$replicas" != "3" ]; then
        print_status "failed" "Replica count was modified."
        exit 1
    fi
    print_status "success" "Replica count unchanged."
}

test_readiness_probe_exists
test_resource_requests_and_limits_exist
test_replicas_not_modified
exit 0
