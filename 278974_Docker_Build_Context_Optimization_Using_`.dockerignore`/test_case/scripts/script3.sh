#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

APP_DIR="/home/user/app"


function test_build_succeeds() {
    cd "$APP_DIR"
    
    echo "Building Docker image with .dockerignore..."
    
    if ! docker build -t ml-app:optimized . >/tmp/docker_build.log 2>&1; then
        print_status "failed" "Lab Failed: Docker build failed. Check Dockerfile and .dockerignore."
        cat /tmp/docker_build.log
        exit 1
    fi
    
    print_status "success" "Lab Passed: Docker build succeeded with .dockerignore."
}


function test_build_context_size() {
    cd "$APP_DIR"
    
    echo "Checking build context size..."
    
    # Build and capture context size from output
    BUILD_OUTPUT=$(docker build --no-cache -t ml-app:optimized . 2>&1)
    
    # Extract context size (look for "Sending build context to Docker daemon")
    CONTEXT_LINE=$(echo "$BUILD_OUTPUT" | grep "Sending build context to Docker daemon")
    
    if [ -z "$CONTEXT_LINE" ]; then
        print_status "failed" "Lab Failed: Could not determine build context size from Docker output."
        exit 1
    fi
    
    echo "Build context: $CONTEXT_LINE"
    
    # Extract size in MB or KB
    if echo "$CONTEXT_LINE" | grep -qE "[0-9.]+GB"; then
        # Context is in GB - this is too large
        print_status "failed" "Lab Failed: Build context is still in GB (should be under 20MB). .dockerignore not effective."
        exit 1
    elif echo "$CONTEXT_LINE" | grep -qE "[0-9]+MB"; then
        # Extract MB value
        SIZE_MB=$(echo "$CONTEXT_LINE" | grep -oE "[0-9.]+" | head -1)
        SIZE_MB=${SIZE_MB%.*}  # Remove decimal
        
        if [ "$SIZE_MB" -gt 20 ]; then
            print_status "failed" "Lab Failed: Build context is ${SIZE_MB}MB (should be under 20MB)."
            exit 1
        fi
    fi
    
    print_status "success" "Lab Passed: Build context is optimized (under 20MB)."
}


function test_required_files_present() {
    cd "$APP_DIR"
    
    echo "Verifying required files are in the built image..."
    
    # Run container temporarily
    docker run -d --name ml-app-validate ml-app:optimized sleep 60 >/dev/null 2>&1
    
    # Check required files exist in container
    if ! docker exec ml-app-validate test -f /app/app.py; then
        docker rm -f ml-app-validate >/dev/null 2>&1
        print_status "failed" "Lab Failed: app.py missing from Docker image."
        exit 1
    fi
    
    if ! docker exec ml-app-validate test -f /app/requirements.txt; then
        docker rm -f ml-app-validate >/dev/null 2>&1
        print_status "failed" "Lab Failed: requirements.txt missing from Docker image."
        exit 1
    fi
    
    if ! docker exec ml-app-validate test -f /app/config.py; then
        docker rm -f ml-app-validate >/dev/null 2>&1
        print_status "failed" "Lab Failed: config.py missing from Docker image."
        exit 1
    fi
    
    # Cleanup
    docker rm -f ml-app-validate >/dev/null 2>&1
    
    print_status "success" "Lab Passed: Required application files present in Docker image."
}


test_build_succeeds
test_build_context_size
test_required_files_present

exit 0