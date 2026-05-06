#!/bin/bash

set -e

IMAGE="fintechpay-python-app"

echo "🚀 Building secure multi-stage Docker image: $IMAGE"

# -------------------------------
# Create secure multi-stage Dockerfile
# -------------------------------
cat << 'EOF' > Dockerfile
# ---------- Builder Stage ----------
FROM python:3.11-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---------- Runtime Stage ----------
FROM python:3.11-slim

# Create non-root user
RUN useradd -m -u 1000 appuser

WORKDIR /app

# Copy only installed dependencies
COPY --from=builder /install /usr/local

# Copy application code
COPY app.py .

# Fix ownership
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

CMD ["python", "app.py"]
EOF

# -------------------------------
# Build image
# -------------------------------
docker build -t "$IMAGE" .

echo "✅ Docker image '$IMAGE' built successfully"
