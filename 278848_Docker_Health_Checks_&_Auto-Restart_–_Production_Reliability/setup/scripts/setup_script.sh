#!/bin/bash

set -euo pipefail

#!/usr/bin/env bash
set -e

echo "======================================"
echo "SECUREBANK LAB SETUP"
echo "======================================"

LAB_DIR="securebank-lab"

# Clean previous runs
rm -rf $LAB_DIR
mkdir -p $LAB_DIR/app

########################################
# App Code
########################################
cat << 'EOF' > $LAB_DIR/app/app.py
from flask import Flask
import os
import time

app = Flask(__name__)

@app.route("/")
def index():
    return "SecureBank running"

@app.route("/health")
def health():
    return "ok", 200

@app.route("/freeze")
def freeze():
    # Simulate app freeze
    time.sleep(300)
    return "frozen"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
EOF

########################################
# Requirements
########################################
cat << 'EOF' > $LAB_DIR/app/requirements.txt
flask==3.0.0
EOF

########################################
# INSECURE Dockerfile (Learner must fix)
########################################
cat << 'EOF' > $LAB_DIR/Dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY app/ /app

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8080

CMD ["python", "app.py"]
EOF

########################################
# docker-compose.yml
########################################
cat << 'EOF' > $LAB_DIR/docker-compose.yml
version: "3.8"

services:
  checkout:
    build:
      context: .
    image: banking-app:secure
    ports:
      - "8080:8080"
EOF

########################################
# Instructions
########################################
cat << 'EOF'

======================================
LAB INSTRUCTIONS
======================================

Your task:

1. Modify the Dockerfile to:
   - Run the container as a NON-ROOT user
   - Add a HEALTHCHECK
   - Follow container security best practices

2. Ensure the image is named:
   banking-app:secure

3. Run:
   docker compose up --build

4. Test failure recovery:
   curl http://localhost:8080/freeze

Expected behavior:
- Container becomes unhealthy
- Docker restarts it automatically

======================================

EOF



echo "Creating/updating ${TARGET_FILE} ..."
chown user:user "${TARGET_FILE}" 2>/dev/null || true
