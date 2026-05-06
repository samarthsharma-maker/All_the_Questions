#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

CREDENTIALS_FILE="/home/user/github_creds.json"

Test7() {

    if [ ! -f "$CREDENTIALS_FILE" ]; then
        print_status "failed" "Missing file: /home/user/github_creds.json"
        return
    fi

    ACCESS_TOKEN=$(jq -r '.access_token' "$CREDENTIALS_FILE")
    USERNAME=$(jq -r '.username' "$CREDENTIALS_FILE")
    REPO_NAME=$(jq -r '.repository_name' "$CREDENTIALS_FILE")

    response=$(curl -s -o /var/tmp/runs.json -w "%{http_code}" \
        -H "Authorization: token $ACCESS_TOKEN" \
        "https://api.github.com/repos/$USERNAME/$REPO_NAME/actions/runs?event=workflow_dispatch&per_page=20")

    if [ "$response" -ne 200 ]; then
        print_status "failed" "Unable to fetch workflow runs (HTTP $response)."
        return
    fi

    run_found=$(jq -r '
        .workflow_runs[]
        | select(.event == "workflow_dispatch" and .conclusion == "success")
        | .id' /var/tmp/runs.json | head -1)

    if [ -n "$run_found" ]; then
        print_status "success" "Found a successful workflow_dispatch run (run ID: $run_found)."
    else
        print_status "failed" "No successful workflow_dispatch run found. After fixing all four bugs, go to the Actions tab in GitHub, click Run workflow, provide values for 'service_name' and 'version', and wait for the run to complete with a green status."
    fi
}

Test7
