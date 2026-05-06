#!/bin/bash
# solution-resource-limits-lab.sh
# Demonstrates proper resource limits to prevent OOMKilled

set -euo pipefail

BASE_DIR="/home/user/datacrunch-solution"

mkdir -p "${BASE_DIR}"

# --------------------------------------------------
# Copy Application Files
# --------------------------------------------------
function copy_files() {
    if [ -d "/home/user/datacrunch-lab" ]; then
        cp /home/user/datacrunch-lab/memory-hog.py "${BASE_DIR}/"
        cp /home/user/datacrunch-lab/cpu-hog.py "${BASE_DIR}/"
    else
        # Create if not exists
        cat > "${BASE_DIR}/memory-hog.py" <<'EOF'
import time
import os
import sys

print(f"Memory Hog (PID: {os.getpid()})")
data = []
chunk_size = 10 * 1024 * 1024
iteration = 0
try:
    while True:
        iteration += 1
        chunk = 'X' * chunk_size
        data.append(chunk)
        memory_mb = (iteration * chunk_size) / (1024 * 1024)
        print(f"Allocated: {memory_mb:.0f} MB")
        sys.stdout.flush()
        time.sleep(2)
except MemoryError:
    print("Out of memory!")
EOF

        cat > "${BASE_DIR}/cpu-hog.py" <<'EOF'
import os
print(f"CPU Hog (PID: {os.getpid()})")
while True:
    _ = sum(i * i for i in range(10000000))
EOF
    fi
}

# --------------------------------------------------
# Create Dockerfiles
# --------------------------------------------------
function create_dockerfiles() {
    cat > "${BASE_DIR}/Dockerfile.memory" <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY memory-hog.py .
CMD ["python", "-u", "memory-hog.py"]
EOF

    cat > "${BASE_DIR}/Dockerfile.cpu" <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY cpu-hog.py .
CMD ["python", "-u", "cpu-hog.py"]
EOF
}

# --------------------------------------------------
# Build Images
# --------------------------------------------------
function build_images() {
    echo ""
    echo "=========================================="
    echo "BUILDING IMAGES"
    echo "=========================================="
    echo ""
    
    cd "${BASE_DIR}"
    docker build -f Dockerfile.memory -t memory-hog .
    docker build -f Dockerfile.cpu -t cpu-hog .
    
    echo ""
    echo "Images built!"
}

# --------------------------------------------------
# Demonstrate Resource Limits
# --------------------------------------------------
function demonstrate_limits() {
    echo ""
    echo "=========================================="
    echo "DEMONSTRATING RESOURCE LIMITS"
    echo "=========================================="
    echo ""
    
    # Clean up
    docker rm -f hog-limited cpu-limited safe-app 2>/dev/null || true
    sleep 1
    
    echo "=========================================="
    echo "TEST 1: Memory Limit (512MB)"
    echo "=========================================="
    echo ""
    
    echo "Starting container with 512MB limit..."
    docker run -d \
        --name hog-limited \
        --memory="512m" \
        --memory-reservation="256m" \
        memory-hog
    
    echo ""
    echo "Monitoring for 30 seconds..."
    echo "(Container will hit limit and get OOMKilled)"
    echo ""
    
    for i in {1..6}; do
        sleep 5
        if docker ps --format "{{.Names}}" | grep -q "hog-limited"; then
            docker stats hog-limited --no-stream
        else
            echo "Container was OOMKilled!"
            break
        fi
    done
    
    echo ""
    echo "Checking OOM status..."
    OOMKILLED=$(docker inspect hog-limited --format='{{.State.OOMKilled}}' 2>/dev/null || echo "unknown")
    EXITCODE=$(docker inspect hog-limited --format='{{.State.ExitCode}}' 2>/dev/null || echo "unknown")
    
    echo "  OOMKilled: $OOMKILLED"
    echo "  Exit Code: $EXITCODE (137 = OOMKilled)"
    
    if [ "$EXITCODE" == "137" ]; then
        echo "  ✓ Container was killed for exceeding memory limit"
    fi
    
    echo ""
    echo "=========================================="
    echo "TEST 2: CPU Limit (0.5 cores)"
    echo "=========================================="
    echo ""
    
    echo "Starting CPU-intensive container with 50% CPU limit..."
    docker run -d \
        --name cpu-limited \
        --cpus="0.5" \
        cpu-hog
    
    sleep 5
    
    echo ""
    echo "Monitoring CPU usage..."
    docker stats cpu-limited --no-stream
    echo ""
    echo "  ✓ Container limited to 50% of one CPU core"
    
    docker rm -f cpu-limited 2>/dev/null || true
    
    echo ""
    echo "=========================================="
    echo "TEST 3: Combined Limits (Production)"
    echo "=========================================="
    echo ""
    
    echo "Starting with both memory AND CPU limits..."
    docker run -d \
        --name safe-app \
        --memory="512m" \
        --memory-reservation="256m" \
        --cpus="1.0" \
        --restart unless-stopped \
        memory-hog
    
    sleep 5
    
    echo ""
    echo "Resource limits:"
    echo "  Memory: 512MB max, 256MB guaranteed"
    echo "  CPU: 1.0 cores max"
    echo "  Restart: unless-stopped"
    echo ""
    
    docker stats safe-app --no-stream
    
    echo ""
    echo "  ✓ Container protected with limits"
    echo "  ✓ Host protected from resource exhaustion"
    echo "  ✓ Will auto-restart if OOMKilled"
    
    # Clean up for tests
    docker rm -f safe-app 2>/dev/null || true
}

# --------------------------------------------------
# Show Comparison
# --------------------------------------------------
function show_comparison() {
    echo ""
    echo ""
    echo "=========================================="
    echo "RESOURCE LIMITS COMPARISON"
    echo "=========================================="
    echo ""
    echo "WITHOUT Limits (DANGEROUS):"
    echo "  docker run -d memory-hog"
    echo ""
    echo "  ✗ Can consume ALL host memory"
    echo "  ✗ Can monopolize ALL CPU cores"
    echo "  ✗ Crashes other containers"
    echo "  ✗ Can crash entire host"
    echo "  ✗ $3M outage (DataCrunch incident)"
    echo ""
    echo "WITH Limits (SAFE):"
    echo "  docker run -d --memory=\"512m\" --cpus=\"1.0\" memory-hog"
    echo ""
    echo "  ✓ Limited to 512MB memory"
    echo "  ✓ Limited to 1 CPU core"
    echo "  ✓ Gets OOMKilled at limit (exit 137)"
    echo "  ✓ Other containers protected"
    echo "  ✓ Host remains stable"
    echo ""
}

# --------------------------------------------------
# Show Monitoring
# --------------------------------------------------
function show_monitoring() {
    echo ""
    echo "=========================================="
    echo "MONITORING COMMANDS"
    echo "=========================================="
    echo ""
    echo "# View all container resources"
    echo "docker stats"
    echo ""
    echo "# View specific container"
    echo "docker stats safe-app --no-stream"
    echo ""
    echo "# Check memory limit"
    echo "docker inspect safe-app --format='{{.HostConfig.Memory}}'"
    echo ""
    echo "# Check if OOMKilled"
    echo "docker inspect safe-app --format='{{.State.OOMKilled}}'"
    echo ""
    echo "# Check exit code"
    echo "docker inspect safe-app --format='{{.State.ExitCode}}'"
    echo "# (137 = OOMKilled)"
    echo ""
    echo "# Update limits on running container"
    echo "docker update --memory=\"1g\" --cpus=\"2.0\" safe-app"
    echo ""
}

# --------------------------------------------------
# Show Summary
# --------------------------------------------------
function show_summary() {
    echo ""
    echo "=========================================="
    echo "RESOURCE LIMITS SOLUTION COMPLETE"
    echo "=========================================="
    echo ""
    echo "Before (DataCrunch Incident):"
    echo "  ✗ No limits on containers"
    echo "  ✗ One container consumed all 64GB RAM"
    echo "  ✗ All 50 containers crashed"
    echo "  ✗ 6-hour outage"
    echo "  ✗ $3M in losses"
    echo ""
    echo "After (With Limits):"
    echo "  ✓ Every container has memory limit"
    echo "  ✓ Every container has CPU limit"
    echo "  ✓ One container cannot crash host"
    echo "  ✓ OOMKilled containers auto-restart"
    echo "  ✓ Platform remains stable"
    echo ""
    echo "Resource Limit Best Practices:"
    echo "  ✓ Always set --memory in production"
    echo "  ✓ Set --cpus for CPU-intensive workloads"
    echo "  ✓ Use --memory-reservation for guarantees"
    echo "  ✓ Monitor with docker stats"
    echo "  ✓ Watch for exit code 137 (OOMKilled)"
    echo "  ✓ Set --restart policy for recovery"
    echo ""
    echo "Files: ${BASE_DIR}"
    echo ""
    echo "=========================================="
    echo "PLATFORM PROTECTED FROM RESOURCE EXHAUSTION"
    echo "=========================================="
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "=========================================="
    echo "IMPLEMENTING RESOURCE LIMITS"
    echo "=========================================="
    echo ""
    
    copy_files
    create_dockerfiles
    build_images
    demonstrate_limits
    show_comparison
    show_monitoring
    show_summary
}

main