#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

Test3() {

    if [ ! -f /var/tmp/workflow.json ]; then
        print_status "failed" "Workflow content not cached. Ensure script_2 ran successfully first."
        return
    fi

    WORKFLOW_CONTENT=$(jq -r '.content' /var/tmp/workflow.json | base64 --decode)

    # Check for the misspelled trigger that must be gone
    if echo "$WORKFLOW_CONTENT" | grep -q "workflow_dipatch"; then
        print_status "failed" "The workflow still contains the misspelled trigger 'workflow_dipatch'. GitHub silently ignores unknown event names — the Run Workflow button will never appear in the Actions UI until this is corrected. Fix: rename 'workflow_dipatch' to 'workflow_dispatch'."
        return
    fi

    # Check the correctly spelled trigger is present
    if echo "$WORKFLOW_CONTENT" | grep -q "workflow_dispatch"; then
        print_status "success" "Trigger event 'workflow_dispatch' is correctly spelled."
    else
        print_status "failed" "No 'workflow_dispatch' trigger found in the workflow. The workflow must use 'on: workflow_dispatch' to support manual triggering from the GitHub Actions UI."
    fi
}

Test3

Test4() {

    if [ ! -f /var/tmp/workflow.json ]; then
        print_status "failed" "Workflow content not cached. Ensure script_2 ran successfully first."
        return
    fi

    WORKFLOW_CONTENT=$(jq -r '.content' /var/tmp/workflow.json | base64 --decode)

    # Check the broken self-hosted label is gone
    if echo "$WORKFLOW_CONTENT" | grep -q "self-hosted-prod"; then
        print_status "failed" "The workflow still has 'runs-on: self-hosted-prod'. This label does not match any registered runner — the job will queue indefinitely and never start. Fix: change 'runs-on' to 'ubuntu-latest'."
        return
    fi

    # Check ubuntu-latest is used
    if echo "$WORKFLOW_CONTENT" | grep -q "ubuntu-latest"; then
        print_status "success" "'runs-on' is correctly set to 'ubuntu-latest'."
    else
        print_status "failed" "The 'runs-on' field is not set to 'ubuntu-latest'. GitHub-hosted runner jobs must use a valid label such as 'ubuntu-latest', 'windows-latest', or 'macos-latest'."
    fi
}

Test4