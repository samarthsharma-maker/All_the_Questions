#!/bin/bash
# setup-flaskapp-part1.sh
# Creates the broken Dockerfile for Flask Challenge — Part 1 (4 builder-stage mistakes)

set -euo pipefail

TARGET_DIR="/home/user/flaskapp-part1"
TARGET_FILE="${TARGET_DIR}/Dockerfile"

echo "Creating directory ${TARGET_DIR} ..."
mkdir -p "${TARGET_DIR}"

echo "Writing broken Dockerfile to ${TARGET_FILE} ..."

cat > "${TARGET_FILE}" <<'EOF'
# -------- Stage 1: Builder --------
FROM python:3.12-slim : builder

WORKDIR /app/app

COPY required.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# -------- Stage 2: Runtime --------
FROM python:3.12-slim AS runtime

WORKDIR /app

COPY --from=builder /app /app

EXPOSE 5050

ENTRYPOINT ["python", "app.py"]
EOF

# Best-effort ownership fix
chown user:user "${TARGET_FILE}" 2>/dev/null || true

echo "Broken Dockerfile created at ${TARGET_FILE}"
echo "This file contains the 4 required builder-stage mistakes for Part 1."
