#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

JENKINSFILE="/home/user/nexaflow-lab/Jenkinsfile"

function test_all_stages_have_steps() {
    local in_stage=0
    local stage_name=""
    local has_steps=0
    local failed_stage=""

    while IFS= read -r line; do
        if echo "$line" | grep -qE "^\s+stage\s*\("; then
            if [ $in_stage -eq 1 ] && [ $has_steps -eq 0 ] && [ -n "$stage_name" ]; then
                failed_stage="$stage_name"
                break
            fi
            in_stage=1
            has_steps=0
            stage_name=$(echo "$line" | grep -oP '(?<=stage\()["\x27][^\)"]+["\x27]' | tr -d '"'"'" || echo "unknown")
        fi

        if echo "$line" | grep -qE "^\s+steps\s*\{"; then
            has_steps=1
        fi
    done < "$JENKINSFILE"

    if [ -n "$failed_stage" ]; then
        print_status "failed" "Lab Failed: Stage '$failed_stage' is missing a 'steps' block. Every stage in a declarative pipeline must contain a steps block."
        exit 1
    fi

    print_status "success" "Lab Passed: All stages contain a valid steps block."
}

function test_no_bare_steps_outside_steps_block() {
    local in_stage=0
    local in_steps=0
    local brace_depth=0

    while IFS= read -r line; do
        if echo "$line" | grep -qE "^\s+stage\s*\("; then
            in_stage=1
            in_steps=0
        fi

        if echo "$line" | grep -qE "^\s+steps\s*\{"; then
            in_steps=1
        fi

        if [ $in_stage -eq 1 ] && [ $in_steps -eq 0 ]; then
            if echo "$line" | grep -qE "^\s+echo\s+" || echo "$line" | grep -qE "^\s+sh\s+"; then
                print_status "failed" "Lab Failed: A step command (echo or sh) was found inside a stage but outside a steps block. All step commands must be wrapped in a steps block."
                exit 1
            fi
        fi
    done < "$JENKINSFILE"

    print_status "success" "Lab Passed: No bare step commands found outside a steps block."
}

test_all_stages_have_steps
test_no_bare_steps_outside_steps_block

print_status "success" "Lab Passed: All stage syntax is valid."
exit 0