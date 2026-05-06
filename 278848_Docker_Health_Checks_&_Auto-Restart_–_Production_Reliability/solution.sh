#!/bin/bash
set -euo pipefail

LAB_DIR="securebank-lab"

mkdir -p "$LAB_DIR"

########################################
# Dockerfile (SECURE, CORRECT)
########################################
cat > "$LAB_DIR/Dockerfile" <<'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system deps for healthcheck
RUN apt-get update \
    && apt-get install -y curl \
    && rm -rf /var/lib/apt/lists/*

# Copy only requirements first (cache-friendly)
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create non-root user
RUN useradd -m appuser

# Copy app code
COPY app/ /app

# Fix ownership BEFORE switching user
RUN chown -R appuser:appuser /app

EXPOSE 8080

USER appuser

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

CMD ["python", "app.py"]
EOF

########################################
# docker-compose.yml
########################################
cat > "$LAB_DIR/docker-compose.yml" <<'EOF'
version: "3.8"

services:
  checkout:
    image: banking-app:secure
    build:
      context: .
    ports:
      - "8080:8080"
    restart: unless-stopped
EOF

echo "======================================"
echo "SOLUTION APPLIED (CORRECT)"
echo "======================================"
echo ""
echo "Run:"
echo "  cd securebank-lab"
echo "  docker compose up --build"
echo ""
echo "Freeze app:"
echo "  curl http://localhost:8080/freeze"
echo ""
echo "Observe:"
echo "  docker ps"
echo "  Container becomes unhealthy and restarts"
echo "======================================"
