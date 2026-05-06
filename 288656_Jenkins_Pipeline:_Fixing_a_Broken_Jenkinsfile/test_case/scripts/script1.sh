#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

JENKINSFILE="/home/user/nexaflow-lab/Jenkinsfile"

function test_jenkinsfile_exists() {
    if [ ! -f "$JENKINSFILE" ]; then
        print_status "failed" "Lab Failed: Jenkinsfile not found at '$JENKINSFILE'."
        exit 1
    fi
    print_status "success" "Lab Passed: Jenkinsfile exists at '$JENKINSFILE'."
}

function test_agent_is_not_none_at_top_level_without_stage_agents() {
    local top_level_agent
    top_level_agent=$(grep -E "^\s+agent\s+" "$JENKINSFILE" | head -1 | awk '{print $2}')

    if [ "$top_level_agent" = "none" ]; then
        local stage_agents
        stage_agents=$(grep -c "agent " "$JENKINSFILE" || true)
        if [ "$stage_agents" -le 1 ]; then
            print_status "failed" "Lab Failed: Top-level agent is set to 'none' but no agent is declared inside any stage. The pipeline has no executor and cannot run."
            exit 1
        fi
    fi

    print_status "success" "Lab Passed: A valid agent declaration is present."
}

function test_agent_declaration_valid() {
    local agent_line
    agent_line=$(grep -E "^\s+agent\s+" "$JENKINSFILE" | head -1)

    if echo "$agent_line" | grep -qE "agent\s+none$"; then
        local has_stage_agent
        has_stage_agent=$(grep -c "agent {" "$JENKINSFILE" || true)
        if [ "$has_stage_agent" -eq 0 ]; then
            print_status "failed" "Lab Failed: 'agent none' is set at the top level but no stage-level agent block was found. Add 'agent any' at the top level or declare an agent inside each stage."
            exit 1
        fi
    fi

    print_status "success" "Lab Passed: Agent declaration is valid and allows pipeline execution."
}

test_jenkinsfile_exists
test_agent_is_not_none_at_top_level_without_stage_agents
test_agent_declaration_valid

print_status "success" "Lab Passed: Jenkinsfile exists and agent configuration is valid."
exit 0