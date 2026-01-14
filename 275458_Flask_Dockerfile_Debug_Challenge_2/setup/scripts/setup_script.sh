#!/bin/bash
set -euo pipefail

TARGET_DIR="/home/user/python-runtime"
DOCKERFILE="${TARGET_DIR}/Dockerfile"

echo "Setting up broken Python runtime-stage Dockerfile at ${DOCKERFILE} ..."
mkdir -p "${TARGET_DIR}"

cat <<'EOF' > "${DOCKERFILE}"
# --------------------- BUILD STAGE (DO NOT MODIFY) ---------------------
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt
COPY . .

# --------------------- RUNTIME STAGE (FIX ONLY THESE ISSUES) ---------------------
FROM python:3.12-slim

# Issue 1: Wrong working directory
WORKDIR //app/api

# Issue 2: Dangerous permissions
RUN chmod -R 777 .

# Issue 3: Incorrect environment variable syntax
ENV PY_ENV= dev

# Issue 4: Wrong port exposed
EXPOSE 9090

# Issue 5: Bad CMD format
CMD "python" "main.py"

EOF

chown user:user "${DOCKERFILE}" 2>/dev/null || true

echo "Broken Dockerfile created at ${DOCKERFILE}."
echo "This file contains the 4 required builder-stage mistakes for Part 2."