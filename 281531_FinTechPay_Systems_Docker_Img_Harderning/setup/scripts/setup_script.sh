#!/bin/bash

set -euo pipefail
TARGET_DIR="/home/user"
PROJECT_DIR="${TARGET_DIR}/python-docker-app"

print_status() { echo -e " $1"; }

print_status "Creating project directory at $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"

print_status "Creating Flask application (app.py)"

cat << 'EOF' > "${PROJECT_DIR}/app.py"
from flask import Flask

app = Flask(__name__)

@app.route("/")
def hello():
    return "Hello from insecure Python app!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
EOF

print_status "Creating requirements.txt"

cat << 'EOF' > "${PROJECT_DIR}/requirements.txt"
flask==2.3.3
EOF


print_status "Creating insecure single-stage Dockerfile"

cat << 'EOF' > "${PROJECT_DIR}/Dockerfile"
FROM python:latest

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8080

CMD ["python", "app.py"]
EOF


print_status "Creating README.md"

cat << 'EOF' > "${PROJECT_DIR}/README.md"
# Python Docker Application

This is a simple Flask application intended for Docker hardening exercises.

The Dockerfile is intentionally insecure and not production-ready.

Your task is to:
- Convert it to a multi-stage build
- Reduce image size
- Run as non-root
- Remove unnecessary layers
EOF

print_status "Setup complete "
print_status "Project created at: $PROJECT_DIR"
print_status "You may now begin the Docker hardening exercise"

chown -R user:user "$TARGET_DIR" 2>/dev/null || true
print_status "Setup script finished."
