#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

JENKINSFILE="/home/user/nexaflow-lab/Jenkinsfile"

VALID_POST_CONDITIONS=("always" "success" "failure" "unstable" "changed" "fixed" "regression" "aborted" "cleanup")

function test_post_block_exists() {
    if ! grep -qE "^\s+post\s*\{" "$JENKINSFILE"; then
        print_status "failed" "Lab Failed: No 'post' block found in the Jenkinsfile. The pipeline requires a post block for cleanup or notification logic."
        exit 1
    fi
    print_status "success" "Lab Passed: A post block is present in the Jenkinsfile."
}

function test_post_block_has_valid_condition() {
    local in_post=0
    local brace_depth=0
    local found_valid=0
    local found_invalid=""

    while IFS= read -r line; do
        if echo "$line" | grep -qE "^\s+post\s*\{"; then
            in_post=1
            brace_depth=1
            continue
        fi

        if [ $in_post -eq 1 ]; then
            local opens closes
            opens=$(echo "$line" | grep -o "{" | wc -l)
            closes=$(echo "$line" | grep -o "}" | wc -l)
            brace_depth=$(( brace_depth + opens - closes ))

            if [ $brace_depth -le 0 ]; then
                in_post=0
                continue
            fi

            # Only check lines at depth 1 inside post block (condition name lines)
            # These look like: "        always {" — a single word followed by {
            if [ $brace_depth -eq 1 ] || ( [ $opens -gt 0 ] && [ $brace_depth -eq 2 ] ); then
                local condition
                condition=$(echo "$line" | grep -oP "^\s+\K[a-z_]+" | head -1)

                if [ -n "$condition" ]; then
                    local is_valid=0
                    for valid in "${VALID_POST_CONDITIONS[@]}"; do
                        if [ "$condition" = "$valid" ]; then
                            is_valid=1
                            found_valid=1
                            break
                        fi
                    done
                    if [ $is_valid -eq 0 ] && echo "$line" | grep -qE "^\s+[a-z_]+\s*\{"; then
                        found_invalid="$condition"
                    fi
                fi
            fi
        fi
    done < "$JENKINSFILE"

    if [ -n "$found_invalid" ]; then
        print_status "failed" "Lab Failed: '$found_invalid' is not a valid post condition. Valid conditions are: always, success, failure, unstable, changed, fixed, regression, aborted, cleanup."
        exit 1
    fi

    if [ $found_valid -eq 0 ]; then
        print_status "failed" "Lab Failed: The post block does not contain any valid condition. Add a valid condition such as 'always', 'success', or 'failure'."
        exit 1
    fi

    print_status "success" "Lab Passed: The post block contains a valid condition."
}

test_post_block_exists
test_post_block_has_valid_condition

print_status "success" "Lab Passed: Post block is correctly configured with a valid condition."
exit 0