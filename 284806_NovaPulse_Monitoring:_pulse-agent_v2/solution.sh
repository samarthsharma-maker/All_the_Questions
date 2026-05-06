#!/bin/bash
# solution-docker-lab2.sh
# Reference solution for the NovaPulse Docker v2 lab.
# Run as: bash solution-docker-lab2.sh

set -euo pipefail

APP_DIR="/home/user/pulse-agent"
IMAGE="pulse-agent:v2"
CONTAINER="pulse-agent-staging"
NETWORK="novapulse-net"

# --------------------------------------------------
# Part C: Discover the issue on the running container
# before touching any files — mirrors the expected workflow.
# --------------------------------------------------
function discover_container_issue() {
    echo "=== [C] Investigating running container ==="
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        echo "Running: docker exec ${CONTAINER} env | grep APP_ENV"
        docker exec "${CONTAINER}" env | grep APP_ENV || true
        echo "→ APP_ENV=production on a staging container. Must be re-run with -e APP_ENV=staging."
    else
        echo "Container not running — skipping."
    fi
    echo ""
}

# --------------------------------------------------
# Part A + B: Corrected Dockerfile
#
# A1: ENTRYPOINT exec form          → binary is PID 1, receives SIGTERM
# A2: HEALTHCHECK exec form + params → no sh per probe, tuned intervals
# A3: ENV APP_ENV + LOG_LEVEL        → safe runtime defaults in image
# B1: BUILD_VERSION stays ARG only   → not promoted to ENV, no leak
# B2: (handled in .dockerignore)
# --------------------------------------------------
function write_dockerfile() {
    cat > "${APP_DIR}/Dockerfile" <<'EOF'
# ---- Stage 1: Build ----
FROM golang:1.21-alpine AS builder

# B1 fix: BUILD_VERSION stays ARG only.
# Do NOT add: ENV BUILD_VERSION=${BUILD_VERSION}
# The value is available during this stage for ldflags etc.,
# but never persists in the final image or any container.
ARG BUILD_VERSION

WORKDIR /build
COPY go.mod ./
RUN go mod download
COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o pulse-agent .
RUN CGO_ENABLED=0 GOOS=linux go build -o healthcheck ./healthcheck/

# ---- Stage 2: Final ----
FROM alpine:3.19

WORKDIR /app

RUN addgroup -S pulse && adduser -S -G pulse pulse

COPY --from=builder /build/pulse-agent  /app/pulse-agent
COPY --from=builder /build/healthcheck  /app/healthcheck
COPY config.yaml /app/config.yaml

RUN chmod +x /app/pulse-agent /app/healthcheck

# A3: Runtime ENV defaults baked into the image.
# Overridable at docker run time with -e, but safe without it.
ENV APP_ENV=production
ENV LOG_LEVEL=info

# A2: HEALTHCHECK in exec form — CMD [...] not CMD-SHELL.
# Binary runs directly, no sh spawned per probe interval.
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD ["/app/healthcheck"]

USER pulse

# A1: ENTRYPOINT in exec form — /app/pulse-agent is PID 1.
# Receives SIGTERM from docker stop → graceful shutdown works.
ENTRYPOINT ["/app/pulse-agent"]
EOF
    echo "[A1/A2/A3/B1] Dockerfile written."
}

# --------------------------------------------------
# Part B2: Corrected .dockerignore
# --------------------------------------------------
function write_dockerignore() {
    cat > "${APP_DIR}/.dockerignore" <<'EOF'
# Dev secrets — never ship
.env
*.env

# Test code — not needed at runtime
tests/

# Editor and OS noise
.DS_Store
*.swp
.idea/
.vscode/

# Git
.git/
.gitignore

# Docker files themselves
Dockerfile
.dockerignore
EOF
    echo "[B2] .dockerignore written."
}

# --------------------------------------------------
# Rebuild image
# --------------------------------------------------
function rebuild() {
    docker rm -f "${CONTAINER}" 2>/dev/null || true
    docker rmi -f "${IMAGE}"    2>/dev/null || true

    echo "Building ${IMAGE}..."
    docker build \
        --build-arg BUILD_VERSION=2.0.0 \
        -t "${IMAGE}" \
        "${APP_DIR}"
}

# --------------------------------------------------
# Part C fix: re-run container with correct APP_ENV
# --------------------------------------------------
function run_container() {
    if ! docker network inspect "${NETWORK}" &>/dev/null; then
        docker network create --driver bridge "${NETWORK}" >/dev/null
    fi

    echo "Running ${CONTAINER} with APP_ENV=staging on ${NETWORK}..."
    docker run -d \
        --name "${CONTAINER}" \
        --network "${NETWORK}" \
        -e APP_ENV=staging \
        "${IMAGE}"
}

# --------------------------------------------------
# Quick verification
# --------------------------------------------------
function verify() {
    echo ""
    echo "=== Verification ==="

    echo ""
    echo "Image:"
    docker image ls "${IMAGE}"

    echo ""
    echo "ENTRYPOINT:"
    docker inspect "${IMAGE}" --format '  {{json .Config.Entrypoint}}'

    echo ""
    echo "HEALTHCHECK:"
    docker inspect "${IMAGE}" \
        --format '  test={{json .Config.Healthcheck.Test}}  interval={{.Config.Healthcheck.Interval}}  timeout={{.Config.Healthcheck.Timeout}}  retries={{.Config.Healthcheck.Retries}}'

    echo ""
    echo "Image ENV (BUILD_VERSION must be absent):"
    docker inspect "${IMAGE}" \
        --format '{{range .Config.Env}}  {{.}}\n{{end}}'

    echo ""
    echo "Container:"
    docker ps --filter "name=${CONTAINER}" \
        --format "  {{.Names}}  {{.Status}}"

    echo ""
    echo "docker exec — live env check:"
    docker exec "${CONTAINER}" sh -c 'env | grep -E "APP_ENV|LOG_LEVEL"'

    echo ""
    echo "docker exec — tests/ and .env absent:"
    local found
    found=$(docker exec "${CONTAINER}" \
        sh -c "find / -name 'main_test.go' -o -name '.env' 2>/dev/null | head -3 || true")
    [ -z "$found" ] \
        && echo "  PASS: neither found" \
        || echo "  FAIL: $found"
}

# --------------------------------------------------
# Summary
# --------------------------------------------------
function summary() {
    echo ""
    echo "=========================================="
    echo "  SOLUTION SUMMARY"
    echo "=========================================="
    echo ""
    echo "  [A1] ENTRYPOINT shell form → exec form"
    echo "       ENTRYPOINT [\"/app/pulse-agent\"]"
    echo "       Binary is PID 1, receives SIGTERM"
    echo ""
    echo "  [A2] HEALTHCHECK added in exec form"
    echo "       --interval=30s --timeout=5s --retries=3"
    echo "       CMD [\"/app/healthcheck\"]"
    echo ""
    echo "  [A3] Runtime ENV defaults added"
    echo "       ENV APP_ENV=production"
    echo "       ENV LOG_LEVEL=info"
    echo ""
    echo "  [B1] BUILD_VERSION no longer promoted to ENV"
    echo "       Removed: ENV BUILD_VERSION=\${BUILD_VERSION}"
    echo ""
    echo "  [B2] .dockerignore fixed"
    echo "       Added: tests/  .env"
    echo ""
    echo "  [C]  Container re-run with correct APP_ENV"
    echo "       Discovered: APP_ENV=production via docker exec"
    echo "       Fixed: docker run -e APP_ENV=staging"
    echo "=========================================="
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    discover_container_issue
    write_dockerfile
    write_dockerignore
    rebuild
    run_container
    verify
    summary
}

main