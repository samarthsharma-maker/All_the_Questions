#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

Test5() {

    if [ ! -f /var/tmp/workflow.json ]; then
        print_status "failed" "Workflow content not cached. Ensure script_2 ran successfully first."
        return
    fi

    WORKFLOW_CONTENT=$(jq -r '.content' /var/tmp/workflow.json | base64 --decode)

    # Check actions/checkout is present at all
    if ! echo "$WORKFLOW_CONTENT" | grep -q "actions/checkout"; then
        print_status "failed" "No 'actions/checkout' step found in the workflow. A GitHub Actions runner starts each job with an empty workspace — repository files are not available until checkout runs. Add 'uses: actions/checkout@v3' as the first step of the release job."
        return
    fi

    checkout_line=$(echo "$WORKFLOW_CONTENT" | grep -n "actions/checkout" | head -1 | cut -d: -f1)
    first_run_line=$(echo "$WORKFLOW_CONTENT" | grep -n "^\s*run:" | head -1 | cut -d: -f1)

    if [ -n "$first_run_line" ] && [ "$checkout_line" -gt "$first_run_line" ]; then
        print_status "failed" "The 'actions/checkout' step is present but it appears after a 'run' step (checkout on line $checkout_line, first run step on line $first_run_line). Steps that execute before checkout operate on an empty workspace with no repository files. Move 'actions/checkout@v3' to be the very first step in the job."
        return
    fi

    print_status "success" "'actions/checkout' is present and appears before any run steps."
}

Test5

Test6() {

    if [ ! -f /var/tmp/workflow.json ]; then
        print_status "failed" "Workflow content not cached. Ensure script_2 ran successfully first."
        return
    fi

    WORKFLOW_CONTENT=$(jq -r '.content' /var/tmp/workflow.json | base64 --decode)

    if echo "$WORKFLOW_CONTENT" | grep -q "continue-on-error: true"; then
        print_status "failed" "'continue-on-error: true' is still present in the workflow. This causes GitHub Actions to mark a step as passed even when it exits with a non-zero code — a failing test suite will produce a green checkmark and the release will proceed as if nothing went wrong. Remove 'continue-on-error: true' from all critical steps, especially the test step."
        return
    fi

    print_status "success" "No step has 'continue-on-error: true'. Test failures will correctly fail the job."
}

Test6