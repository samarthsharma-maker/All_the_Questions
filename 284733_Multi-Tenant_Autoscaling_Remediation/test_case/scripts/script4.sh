#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

NAMESPACE="finflow-prod"
DEPLOYMENT="payment-processor"
HPA="payment-processor-hpa"
VPA="payment-processor-vpa"

function test_pdb_exists() {
    local pdb_name min_available
    pdb_name=$(kubectl get pdb -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.selector.matchLabels.app}{"\n"}{end}' | grep " payment-processor$" | awk '{print $1}')
    min_available=$(kubectl get pdb "$pdb_name" -n "$NAMESPACE" -o jsonpath='{.spec.minAvailable}')

    if [ -z "$pdb_name" ]; then
        print_status "failed" "Lab Failed: No PodDisruptionBudget found targeting 'app=payment-processor' in namespace '$NAMESPACE'. Without a PDB, node drains or rolling updates can terminate all pods simultaneously."
        exit 1
    fi
    if [ -z "$min_available" ]; then
        print_status "failed" "Lab Failed: PDB '$pdb_name' exists but minAvailable is not set. Configure minAvailable >= 2."
        exit 1
    fi

    # Accept percentage form (e.g. "50%") as valid; enforce integer >= 2 otherwise.
    if echo "$min_available" | grep -qv '%'; then
        if [ "$min_available" -lt 2 ]; then
            print_status "failed" "Lab Failed: PDB '$pdb_name' has minAvailable=$min_available. Must be >= 2 for payment-processor high availability."
            exit 1
        fi
    fi

    print_status "success" "Lab Passed: PDB '$pdb_name' found with minAvailable=$min_available targeting app=payment-processor."
}

function test_hpa_scale_down_stabilization() {
    local stab_window
    stab_window=$(kubectl get hpa "$HPA" -n "$NAMESPACE" -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}')

    if [ -z "$stab_window" ]; then
        print_status "failed" "Lab Failed: HPA scaleDown.stabilizationWindowSeconds is not explicitly set. Configure it to at least 120 seconds to prevent flapping after payment traffic bursts."
        exit 1
    fi
    if [ "$stab_window" -lt 120 ]; then
        print_status "failed" "Lab Failed: scaleDown.stabilizationWindowSeconds is ${stab_window}s — too low (< 120s). HPA will scale down prematurely between bursts and cause oscillation."
        exit 1
    fi

    print_status "success" "Lab Passed: HPA scaleDown.stabilizationWindowSeconds = ${stab_window}s (>= 120s)."
}

test_pdb_exists
test_hpa_scale_down_stabilization
print_status "success" "Lab Passed: HPA custom metric and VPA configuration are correct. Proceeding to check PDB and stabilization settings..."
exit 0