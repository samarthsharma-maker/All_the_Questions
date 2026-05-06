#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

APP_DIR="/home/user/app"
DOCKERIGNORE="$APP_DIR/.dockerignore"


function test_dockerignore_exists() {
    if [ ! -f "$DOCKERIGNORE" ]; then
        print_status "failed" "Lab Failed: .dockerignore file does not exist in /app directory."
        exit 1
    fi
    print_status "success" "Lab Passed: .dockerignore file exists."
}


function test_excludes_data_directory() {
    if ! grep -qE "^data/" "$DOCKERIGNORE"; then
        print_status "failed" "Lab Failed: .dockerignore must exclude 'data/' directory."
        exit 1
    fi
    print_status "success" "Lab Passed: .dockerignore excludes data/ directory."
}


function test_excludes_models_directory() {
    if ! grep -qE "^models/" "$DOCKERIGNORE"; then
        print_status "failed" "Lab Failed: .dockerignore must exclude 'models/' directory."
        exit 1
    fi
    print_status "success" "Lab Passed: .dockerignore excludes models/ directory."
}


function test_excludes_pycache() {
    if ! grep -qE "__pycache__|\.pyc" "$DOCKERIGNORE"; then
        print_status "failed" "Lab Failed: .dockerignore must exclude __pycache__/ or *.pyc files."
        exit 1
    fi
    print_status "success" "Lab Passed: .dockerignore excludes Python cache files."
}


function test_excludes_tests() {
    if ! grep -qE "tests/|\.pytest_cache|test_.*\.py" "$DOCKERIGNORE"; then
        print_status "failed" "Lab Failed: .dockerignore must exclude tests/ or .pytest_cache/ directories."
        exit 1
    fi
    print_status "success" "Lab Passed: .dockerignore excludes test directories."
}


function test_excludes_git() {
    if ! grep -qE "^\.git/" "$DOCKERIGNORE"; then
        print_status "failed" "Lab Failed: .dockerignore must exclude .git/ directory."
        exit 1
    fi
    print_status "success" "Lab Passed: .dockerignore excludes .git/ directory."
}


test_dockerignore_exists
test_excludes_data_directory
test_excludes_models_directory
test_excludes_pycache
test_excludes_tests
test_excludes_git

exit 0