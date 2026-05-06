#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

APP_DIR="/home/user/app"
DOCKERIGNORE="$APP_DIR/.dockerignore"


function test_excludes_venv() {
    if ! grep -qE "venv/|\.venv/" "$DOCKERIGNORE"; then
        print_status "failed" "Lab Failed: .dockerignore must exclude venv/ or .venv/ directories."
        exit 1
    fi
    print_status "success" "Lab Passed: .dockerignore excludes virtual environment directories."
}


function test_excludes_logs() {
    if ! grep -qE "logs/|\*\.log" "$DOCKERIGNORE"; then
        print_status "failed" "Lab Failed: .dockerignore must exclude logs/ directory or *.log files."
        exit 1
    fi
    print_status "success" "Lab Passed: .dockerignore excludes log files."
}


function test_excludes_env_files() {
    if ! grep -qE "^\.env" "$DOCKERIGNORE"; then
        print_status "failed" "Lab Failed: .dockerignore must exclude .env files (security risk)."
        exit 1
    fi
    print_status "success" "Lab Passed: .dockerignore excludes .env files (good security practice)."
}


function test_excludes_documentation() {
    if ! grep -qE "README\.md|\*\.md" "$DOCKERIGNORE"; then
        print_status "failed" "Lab Failed: .dockerignore should exclude README.md or *.md documentation files."
        exit 1
    fi
    print_status "success" "Lab Passed: .dockerignore excludes documentation files."
}


function test_file_not_empty() {
    if [ ! -s "$DOCKERIGNORE" ]; then
        print_status "failed" "Lab Failed: .dockerignore file is empty."
        exit 1
    fi
    
    # Check it has at least 8 non-comment, non-empty lines
    LINE_COUNT=$(grep -v "^#" "$DOCKERIGNORE" | grep -v "^$" | wc -l)
    
    if [ "$LINE_COUNT" -lt 8 ]; then
        print_status "failed" "Lab Failed: .dockerignore must have at least 8 exclusion patterns (found: $LINE_COUNT)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: .dockerignore has sufficient exclusion patterns ($LINE_COUNT patterns)."
}


test_excludes_venv
test_excludes_logs
test_excludes_env_files
test_excludes_documentation
test_file_not_empty

exit 0