#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

CREDENTIALS_FILE="/home/user/github_creds.json"
WORKFLOW_PATH=".github/workflows/service-release.yml"
CREDENTIALS_FILE="/home/user/github_creds.json"

Test1() {

    if [ ! -f "$CREDENTIALS_FILE" ]; then
        print_status "failed" "Missing file: /home/user/github_creds.json"
        return
    fi

    ACCESS_TOKEN=$(jq -r '.access_token // empty' "$CREDENTIALS_FILE")

    if [ -z "$ACCESS_TOKEN" ]; then
        print_status "failed" "access_token missing in github_creds.json"
        return
    fi

    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $ACCESS_TOKEN" \
        https://api.github.com/user)

    if [ "$response" -eq 200 ]; then
        print_status "success" "GitHub credentials are valid."
    else
        print_status "failed" "GitHub authentication failed (HTTP $response)."
    fi
}

Test1

Test2() {

    if [ ! -f "$CREDENTIALS_FILE" ]; then
        print_status "failed" "Missing file: /home/user/github_creds.json"
        return
    fi

    ACCESS_TOKEN=$(jq -r '.access_token' "$CREDENTIALS_FILE")
    USERNAME=$(jq -r '.username' "$CREDENTIALS_FILE")
    REPO_NAME=$(jq -r '.repository_name' "$CREDENTIALS_FILE")

    # Verify repo exists
    repo_response=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $ACCESS_TOKEN" \
        https://api.github.com/repos/$USERNAME/$REPO_NAME)

    if [ "$repo_response" -ne 200 ]; then
        print_status "failed" "Repository '$REPO_NAME' not found (HTTP $repo_response)."
        return
    fi

    # Fetch workflow file and cache content for subsequent scripts
    file_response=$(curl -s -o /var/tmp/workflow.json -w "%{http_code}" \
        -H "Authorization: token $ACCESS_TOKEN" \
        https://api.github.com/repos/$USERNAME/$REPO_NAME/contents/$WORKFLOW_PATH)

    if [ "$file_response" -eq 200 ]; then
        print_status "success" "Workflow file 'service-release.yml' exists in repository."
    else
        print_status "failed" "Workflow file '.github/workflows/service-release.yml' not found (HTTP $file_response). Ensure the file is committed and pushed to the default branch."
    fi
}

Test2