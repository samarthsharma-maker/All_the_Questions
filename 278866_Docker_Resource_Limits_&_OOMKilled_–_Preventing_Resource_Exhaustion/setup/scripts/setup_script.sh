#!/bin/bash

set -euo pipefail

function setup_app_directory() {
    local app_dir="/app"
    
    if [ -d "$app_dir" ]; then
        echo "Cleaning up existing /app directory..."
        rm -rf "$app_dir"
    fi
    
    echo "Creating application directory: $app_dir"
    mkdir -p "$app_dir"
    cd "$app_dir"
}

function create_python_app() {
    echo "Creating Python Flask application..."
    
    cat > /app/app.py <<'EOF'
from flask import Flask, jsonify
import config

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({
        "status": "healthy",
        "service": "ml-app",
        "version": config.VERSION
    })

@app.route('/')
def index():
    return jsonify({
        "message": "ML Application API",
        "endpoints": ["/health", "/"]
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
EOF

    cat > /app/config.py <<'EOF'
VERSION = "1.0.0"
APP_NAME = "ml-app"
DEBUG = False
EOF

    cat > /app/utils.py <<'EOF'
def validate_data(data):
    """Validate input data"""
    return True

def preprocess(data):
    """Preprocess data"""
    return data
EOF

    cat > /app/requirements.txt <<'EOF'
flask==2.3.0
werkzeug==2.3.0
EOF
}

function create_dockerfile() {
    echo "Creating Dockerfile..."
    
    cat > /app/Dockerfile <<'EOF'
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["python", "app.py"]
EOF
}

function create_bloat_files() {
    echo "Creating bloat files to simulate real scenario..."
    
    # Data directory (~80MB with empty files for structure)
    mkdir -p /app/data
    touch /app/data/train.csv
    touch /app/data/test.csv  
    touch /app/data/validation.csv
    # Create one actual 80MB file
    dd if=/dev/zero of=/app/data/large_dataset.csv bs=1M count=80 2>/dev/null
    
    # Models directory (~40MB)
    mkdir -p /app/models
    dd if=/dev/zero of=/app/models/model_v1.pkl bs=1M count=20 2>/dev/null
    dd if=/dev/zero of=/app/models/model_v2.pkl bs=1M count=20 2>/dev/null
    
    # __pycache__ (~20MB)
    mkdir -p /app/__pycache__
    dd if=/dev/zero of=/app/__pycache__/app.cpython-39.pyc bs=1M count=10 2>/dev/null
    dd if=/dev/zero of=/app/__pycache__/config.cpython-39.pyc bs=1M count=10 2>/dev/null
    
    # .pytest_cache (~30MB)
    mkdir -p /app/.pytest_cache
    dd if=/dev/zero of=/app/.pytest_cache/cache.db bs=1M count=30 2>/dev/null
    
    # Tests directory (small files)
    mkdir -p /app/tests
    cat > /app/tests/test_app.py <<'EOF'
def test_health():
    assert True

def test_config():
    assert True
EOF
    cat > /app/tests/test_utils.py <<'EOF'
def test_validation():
    assert True
EOF
    
    # .git directory (~20MB)
    mkdir -p /app/.git/objects
    dd if=/dev/zero of=/app/.git/objects/pack.idx bs=1M count=20 2>/dev/null
    
    # venv (~30MB)
    mkdir -p /app/venv/lib/python3.9/site-packages
    dd if=/dev/zero of=/app/venv/lib/python3.9/site-packages/large.so bs=1M count=30 2>/dev/null
    
    # Logs (~10MB)
    mkdir -p /app/logs
    dd if=/dev/zero of=/app/logs/app.log bs=1M count=10 2>/dev/null
    
    # .env file (secrets)
    cat > /app/.env <<'EOF'
SECRET_KEY=super-secret-key-12345
DATABASE_PASSWORD=production-password
API_KEY=secret-api-key-67890
EOF

    # Documentation
    cat > /app/README.md <<'EOF'
# ML Application
This is a sample ML application for Docker optimization lab.
EOF

    cat > /app/.gitignore <<'EOF'
__pycache__/
*.pyc
.env
venv/
EOF
}

function cleanup_docker() {
    echo "Cleaning up old Docker images..."
    docker rmi ml-app:baseline 2>/dev/null || true
    docker rmi ml-app:optimized 2>/dev/null || true
    docker rm -f ml-app-test 2>/dev/null || true
}

setup_app_directory
create_python_app
create_dockerfile
create_bloat_files
cleanup_docker

echo ""
echo "=========================================="
echo "Setup complete!"
echo "=========================================="
echo "Application directory: /app"
echo "Total directory size: $(du -sh /app 2>/dev/null | cut -f1)"
echo ""
echo "Files created:"
echo "  - Python application: app.py, config.py, utils.py"
echo "  - Dependencies: requirements.txt"
echo "  - Docker: Dockerfile"
echo "  - Bloat: data/ (~80MB), models/ (~40MB), caches, logs, etc."
echo ""
echo "=========================================="
echo "Setting proper ownership..."
echo "=========================================="
# Ensure files are owned by 'user' account (not root)
# This allows students to edit files without permission issues
chown -R user:user /app 2>/dev/null || true
echo "✓ Files owned by user:user"
echo ""
echo "=========================================="
echo "YOUR TASK:"
echo "=========================================="
echo "Create .dockerignore to optimize build context"
echo "  Current: ~200MB"
echo "  Target:  <20MB"
echo ""

exit 0