#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

JENKINSFILE="/home/user/nexaflow-lab/Jenkinsfile"

function test_deploy_env_defined_in_environment_block() {
    local in_env_block=0
    local deploy_env_defined=0

    while IFS= read -r line; do
        if echo "$line" | grep -qE "^\s+environment\s*\{"; then
            in_env_block=1
            continue
        fi

        if [ $in_env_block -eq 1 ]; then
            if echo "$line" | grep -qE "^\s+DEPLOY_ENV\s*="; then
                deploy_env_defined=1
            fi
            if echo "$line" | grep -qE "^\s+\}"; then
                in_env_block=0
            fi
        fi
    done < "$JENKINSFILE"

    if [ $deploy_env_defined -eq 0 ]; then
        print_status "failed" "Lab Failed: 'DEPLOY_ENV' is referenced in the Deploy stage but is not defined in the environment block. Add 'DEPLOY_ENV = \"<value>\"' to the environment block."
        exit 1
    fi

    print_status "success" "Lab Passed: 'DEPLOY_ENV' is defined in the environment block."
}

function test_no_undefined_variables_in_stages() {
    local in_env_block=0
    local env_vars=()

    while IFS= read -r line; do
        if echo "$line" | grep -qE "^\s+environment\s*\{"; then
            in_env_block=1
            continue
        fi

        if [ $in_env_block -eq 1 ]; then
            if echo "$line" | grep -qE "^\s+\}"; then
                in_env_block=0
                continue
            fi
            local var
            var=$(echo "$line" | grep -oP "^\s+\K[A-Z_0-9]+" | head -1)
            if [ -n "$var" ]; then
                env_vars+=("$var")
            fi
        fi
    done < "$JENKINSFILE"

    local used_vars
    used_vars=$(grep -oP '\$\{\K[A-Z_0-9]+(?=\})' "$JENKINSFILE" | sort -u)

    while IFS= read -r used_var; do
        if [ -z "$used_var" ]; then
            continue
        fi
        if [ "$used_var" = "BUILD_NUMBER" ]; then
            continue
        fi
        local found=0
        for defined_var in "${env_vars[@]}"; do
            if [ "$defined_var" = "$used_var" ]; then
                found=1
                break
            fi
        done
        if [ $found -eq 0 ]; then
            print_status "failed" "Lab Failed: Variable '\${$used_var}' is used in the pipeline but not defined in the environment block."
            exit 1
        fi
    done <<< "$used_vars"

    print_status "success" "Lab Passed: All variables referenced in the pipeline are defined in the environment block."
}

test_deploy_env_defined_in_environment_block
test_no_undefined_variables_in_stages

print_status "success" "Lab Passed: Environment block is correctly defined and all variables are resolvable."
exit 0