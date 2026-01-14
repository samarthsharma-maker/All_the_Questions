#!/bin/bash

set -euo pipefail

function setup_namespace() {
    local namespace="techflow-prod"
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        echo "Creating namespace: $namespace"
    fi
}

setup_namespace
exit 0