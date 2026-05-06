#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

APP_DIR="/home/user/app"


function test_excluded_files_not_in_image() {
    echo "Verifying excluded files are NOT in Docker image..."
    
    # Run container temporarily
    docker run -d --name ml-app-validate ml-app:optimized sleep 60 >/dev/null 2>&1
    
    # Check that excluded directories DON'T exist
    if docker exec ml-app-validate test -d /app/data; then
        docker rm -f ml-app-validate >/dev/null 2>&1
        print_status "failed" "Lab Failed: data/ directory should NOT be in Docker image."
        exit 1
    fi
    
    if docker exec ml-app-validate test -d /app/models; then
        docker rm -f ml-app-validate >/dev/null 2>&1
        print_status "failed" "Lab Failed: models/ directory should NOT be in Docker image."
        exit 1
    fi
    
    if docker exec ml-app-validate test -d /app/.git; then
        docker rm -f ml-app-validate >/dev/null 2>&1
        print_status "failed" "Lab Failed: .git/ directory should NOT be in Docker image."
        exit 1
    fi
    
    if docker exec ml-app-validate test -d /app/venv; then
        docker rm -f ml-app-validate >/dev/null 2>&1
        print_status "failed" "Lab Failed: venv/ directory should NOT be in Docker image."
        exit 1
    fi
    
    if docker exec ml-app-validate test -f /app/.env; then
        docker rm -f ml-app-validate >/dev/null 2>&1
        print_status "failed" "Lab Failed: .env file should NOT be in Docker image (security risk)."
        exit 1
    fi
    
    # Cleanup
    docker rm -f ml-app-validate >/dev/null 2>&1
    
    print_status "success" "Lab Passed: Excluded files/directories are NOT in Docker image."
}


function test_application_runs() {
    echo "Testing if application runs correctly..."
    
    # Stop any existing container
    docker rm -f ml-app-test >/dev/null 2>&1 || true
    
    # Run the application
    if ! docker run -d -p 8000:8000 --name ml-app-test ml-app:optimized >/dev/null 2>&1; then
        print_status "failed" "Lab Failed: Could not start application container."
        exit 1
    fi
    
    # Wait for application to start
    sleep 5
    
    # Check if container is still running
    if ! docker ps | grep -q ml-app-test; then
        docker logs ml-app-test
        docker rm -f ml-app-test >/dev/null 2>&1
        print_status "failed" "Lab Failed: Application container exited unexpectedly."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Application container is running."
}


function test_health_endpoint() {
    echo "Testing application health endpoint..."
    
    # Try to curl the health endpoint
    RESPONSE=$(curl -s http://localhost:8000/health 2>/dev/null || echo "")
    
    if [ -z "$RESPONSE" ]; then
        docker logs ml-app-test
        docker rm -f ml-app-test >/dev/null 2>&1
        print_status "failed" "Lab Failed: Could not reach application health endpoint."
        exit 1
    fi
    
    # Check if response contains expected fields
    if ! echo "$RESPONSE" | grep -q "healthy"; then
        docker logs ml-app-test
        docker rm -f ml-app-test >/dev/null 2>&1
        print_status "failed" "Lab Failed: Health endpoint response incorrect."
        exit 1
    fi
    
    # Cleanup
    docker rm -f ml-app-test >/dev/null 2>&1
    
    print_status "success" "Lab Passed: Application health endpoint works correctly."
}


test_excluded_files_not_in_image
test_application_runs
test_health_endpoint

exit 0