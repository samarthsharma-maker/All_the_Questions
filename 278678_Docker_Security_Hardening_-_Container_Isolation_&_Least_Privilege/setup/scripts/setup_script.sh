#!/bin/bash


set -euo pipefail

BASE_DIR="/home/user/securebank-lab"

mkdir -p "${BASE_DIR}/app"

function create_python_app() {
    cat > "${BASE_DIR}/app/app.py" <<'EOF'
from flask import Flask, jsonify
import os
import sys

app = Flask(__name__)

@app.route('/')
def home():
    uid = os.getuid()
    gid = os.getgid()
    return f'SecureBank API - Running as UID: {uid}, GID: {gid}\n'

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'uid': os.getuid(),
        'gid': os.getgid(),
        'user': os.getenv('USER', 'unknown')
    })

@app.route('/api/balance')
def balance():
    return jsonify({
        'account': '****1234',
        'balance': 50000.00,
        'currency': 'USD'
    })

if __name__ == '__main__':
    print(f"Starting server as UID: {os.getuid()}, GID: {os.getgid()}")
    app.run(host='0.0.0.0', port=8080, debug=False)
EOF

    cat > "${BASE_DIR}/app/requirements.txt" <<'EOF'
flask==3.0.0
werkzeug==3.0.1
gunicorn==21.2.0
EOF

    cat > "${BASE_DIR}/app/healthcheck.py" <<'EOF'
import sys
import urllib.request

try:
    response = urllib.request.urlopen('http://localhost:8080/health', timeout=2)
    if response.status == 200:
        sys.exit(0)
    else:
        sys.exit(1)
except Exception:
    sys.exit(1)
EOF
}

function create_insecure_dockerfile() {
    cat > "${BASE_DIR}/Dockerfile" <<'EOF'
# INSECURE DOCKERFILE - DO NOT USE IN PRODUCTION!
# Multiple PCI-DSS violations present

FROM python:3.11

WORKDIR /app

# SECURITY VIOLATION 1: Hardcoded secrets!
ENV DB_PASSWORD=SuperSecret123!
ENV API_KEY=sk_live_51234567890abcdef
ENV SECRET_KEY=my-super-secret-flask-key-12345

# SECURITY VIOLATION 2: Installing unnecessary packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    vim \
    net-tools \
    netcat-traditional \
    && rm -rf /var/lib/apt/lists/*

# Copy application files
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

# SECURITY VIOLATION 3: Exposing unnecessary ports
EXPOSE 8080
EXPOSE 22
EXPOSE 9090

# SECURITY VIOLATION 4: No USER directive - runs as root!
# SECURITY VIOLATION 5: No health check
# SECURITY VIOLATION 6: Writable filesystem
# SECURITY VIOLATION 7: No resource limits

CMD ["python", "app.py"]
EOF
}

function create_docker_compose() {
    cat > "${BASE_DIR}/docker-compose.insecure.yml" <<'EOF'
version: '3.8'

services:
  banking-app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: banking-app-insecure
    ports:
      - "8080:8080"
    # SECURITY VIOLATIONS:
    # - No user specified (runs as root)
    # - No memory limits
    # - No CPU limits
    # - No capability restrictions
    # - No read-only filesystem
    environment:
      - FLASK_ENV=production
EOF
}

function create_readme() {
    cat > "${BASE_DIR}/README.md" <<'EOF'
# SecureBank Docker Security Lab (Python)

## Current Insecure State

This Docker setup has CRITICAL security vulnerabilities:

### Security Violations

1. **Running as root (UID 0)**
2. **Hardcoded secrets in Dockerfile**
3. **No resource limits**
4. **All default capabilities**
5. **Writable root filesystem**
6. **No security profiles**

## Build and Run (Insecure)

```bash
cd /home/user/securebank-lab

# Build the insecure image
docker build -t banking-app:insecure .

# Run insecure container
docker run -d --name banking-app-insecure -p 8080:8080 banking-app:insecure

# Check what user it's running as
docker exec banking-app-insecure id
# Output: uid=0(root) gid=0(root)  ❌

# View hardcoded secrets
docker history banking-app:insecure | grep -i password
```

## Test the App

```bash
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/api/balance
```

## Your Mission

Harden this container to meet PCI-DSS requirements!
EOF
}

function demonstrate_vulnerabilities() {
    echo ""
    echo "=========================================="
    echo "BUILDING INSECURE CONTAINER"
    echo "=========================================="
    echo ""
    
    cd "${BASE_DIR}"
    docker build -t banking-app:insecure . || true
    
    echo ""
    echo "=========================================="
    echo "DEMONSTRATING SECURITY VIOLATIONS"
    echo "=========================================="
    echo ""
    
    # Start container
    docker rm -f banking-app-insecure 2>/dev/null || true
    docker run -d --name banking-app-insecure -p 8080:8080 banking-app:insecure 2>/dev/null || true
    
    # Wait for container to start
    sleep 3
    
    echo "1. Checking user (should be root - INSECURE!):"
    docker exec banking-app-insecure id 2>/dev/null || echo "  Container not running"
    
    echo ""
    echo "2. Checking for hardcoded secrets in image:"
    docker history banking-app:insecure 2>/dev/null | grep -E "PASSWORD|SECRET|KEY" | head -3 || echo "  Build image first"
    
    echo ""
    echo "3. Testing filesystem (should be writable - INSECURE!):"
    if docker exec banking-app-insecure touch /test.txt 2>/dev/null; then
        echo "  ✗ Root filesystem is WRITABLE (insecure!)"
        docker exec banking-app-insecure rm /test.txt 2>/dev/null || true
    else
        echo "  Container not running"
    fi
    
    echo ""
    echo "4. Testing application:"
    sleep 2
    curl -s http://localhost:8080/ 2>/dev/null || echo "  Application starting..."
    
    echo ""
    echo ""
    echo "=========================================="
    echo "⚠️  CRITICAL PCI-DSS VIOLATIONS DETECTED!"
    echo "=========================================="
    echo ""
}

function show_instructions() {
    chown -R user:user "${BASE_DIR}" 2>/dev/null || true
    
    echo ""
    echo "=========================================="
    echo "SECUREBANK DOCKER SECURITY LAB (PYTHON)"
    echo "=========================================="
    echo ""
    echo "Lab files created in: ${BASE_DIR}"
    echo ""
    echo "Files created:"
    echo "  ${BASE_DIR}/Dockerfile (INSECURE)"
    echo "  ${BASE_DIR}/app/app.py"
    echo "  ${BASE_DIR}/app/requirements.txt"
    echo "  ${BASE_DIR}/app/healthcheck.py"
    echo "  ${BASE_DIR}/docker-compose.insecure.yml"
    echo "  ${BASE_DIR}/README.md"
    echo ""
    echo "=========================================="
    echo "SECURITY VIOLATIONS:"
    echo "=========================================="
    echo ""
    echo "1. ❌ Running as root (UID 0)"
    echo "2. ❌ Hardcoded secrets (DB_PASSWORD, API_KEY, SECRET_KEY)"
    echo "3. ❌ No resource limits (memory, CPU)"
    echo "4. ❌ All default capabilities"
    echo "5. ❌ Writable root filesystem"
    echo "6. ❌ No security profiles"
    echo "7. ❌ Large image with unnecessary packages"
    echo ""
    echo "=========================================="
    echo "YOUR MISSION:"
    echo "=========================================="
    echo ""
    echo "Create a hardened Dockerfile that:"
    echo ""
    echo "1. RUNS AS NON-ROOT USER"
    echo "   - Add USER directive"
    echo "   - Create appuser with UID 1000"
    echo ""
    echo "2. REMOVES HARDCODED SECRETS"
    echo "   - Delete ENV statements with secrets"
    echo "   - Use runtime environment variables"
    echo ""
    echo "3. USES MULTI-STAGE BUILD"
    echo "   - Build stage: Install dependencies"
    echo "   - Final stage: Minimal runtime image"
    echo ""
    echo "4. IMPLEMENTS RESOURCE LIMITS"
    echo "   - docker run --memory=512m --cpus=0.5"
    echo ""
    echo "5. DROPS CAPABILITIES"
    echo "   - docker run --cap-drop=ALL"
    echo ""
    echo "6. READ-ONLY ROOT FILESYSTEM"
    echo "   - docker run --read-only --tmpfs /tmp"
    echo ""
    echo "7. APPLIES SECURITY PROFILES"
    echo "   - docker run --security-opt=no-new-privileges"
    echo ""
    echo "=========================================="
    echo "CONTAINER ACCESS:"
    echo "=========================================="
    echo ""
    echo "Application: http://localhost:8080"
    echo "Health check: http://localhost:8080/health"
    echo "API endpoint: http://localhost:8080/api/balance"
    echo ""
    echo "=========================================="
}

function main() {
    create_python_app
    create_insecure_dockerfile
    create_docker_compose
    create_readme
    demonstrate_vulnerabilities
    show_instructions
}

main