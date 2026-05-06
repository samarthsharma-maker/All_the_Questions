#!/bin/bash
# solution-docker-lab.sh
# Writes the correct Dockerfile, builds the image, and runs the container.
# Run as: bash solution-docker-lab.sh

set -euo pipefail

APP_DIR="/home/user/pulse-agent"
IMAGE="pulse-agent:latest"
CONTAINER="pulse-agent"
NETWORK="novapulse-net"

# --------------------------------------------------
# Write the correct Dockerfile
#
# Stage 1 (builder): golang:1.21-alpine
#   - Downloads dependencies
#   - Builds a static binary with CGO_ENABLED=0 GOOS=linux
#
# Stage 2 (final): alpine:3.19
#   - Creates non-root user "pulse"
#   - Copies only the binary and config from build context / builder
#   - Sets WORKDIR, USER, and CMD
#   - Does NOT contain the Go toolchain, source, or build cache
# --------------------------------------------------
function write_dockerfile() {
    cat > "${APP_DIR}/Dockerfile" <<'EOF'
# ---- Stage 1: Build ----
FROM golang:1.21-alpine AS builder

WORKDIR /build

# Copy module files first to cache the download layer independently
# of source changes — only re-downloads when go.mod/go.sum change.
COPY go.mod ./
RUN go mod download

# Copy source and build a fully static binary.
# CGO_ENABLED=0  — disables cgo, produces a pure Go static binary
# GOOS=linux     — targets Linux regardless of build host OS
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o pulse-agent .

# ---- Stage 2: Final runtime image ----
FROM alpine:3.19

WORKDIR /app

# Create a dedicated non-root user and group.
# -D means no password; -H means no home directory.
RUN addgroup -S pulse && adduser -S -G pulse pulse

# Copy only the compiled binary from the builder stage
COPY --from=builder /build/pulse-agent /app/pulse-agent

# Copy the static config from the build context
COPY config.yaml /app/config.yaml

# Ensure the binary is executable (defensive — builder sets this, but explicit is clear)
RUN chmod +x /app/pulse-agent

# Drop to non-root before the entrypoint
USER pulse

CMD ["/app/pulse-agent"]
EOF
    echo "Dockerfile written to ${APP_DIR}/Dockerfile"
}

# --------------------------------------------------
# Remove any previous container and image so the
# build is clean and the run does not conflict
# --------------------------------------------------
function cleanup() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        echo "Removing existing container '${CONTAINER}'..."
        docker rm -f "${CONTAINER}"
    fi

    if docker image inspect "${IMAGE}" &>/dev/null; then
        echo "Removing existing image '${IMAGE}'..."
        docker rmi -f "${IMAGE}"
    fi
}

# --------------------------------------------------
# Build the image
# --------------------------------------------------
function build_image() {
    echo "Building image '${IMAGE}'..."
    docker build -t "${IMAGE}" "${APP_DIR}"
}

# --------------------------------------------------
# Run the container on the correct network
# --------------------------------------------------
function run_container() {
    # Ensure the network exists (setup script creates it, but defensive)
    if ! docker network inspect "${NETWORK}" &>/dev/null; then
        echo "Creating network '${NETWORK}'..."
        docker network create --driver bridge "${NETWORK}"
    fi

    echo "Running container '${CONTAINER}' on network '${NETWORK}'..."
    docker run -d \
        --name "${CONTAINER}" \
        --network "${NETWORK}" \
        "${IMAGE}"
}

# --------------------------------------------------
# Verify
# --------------------------------------------------
function verify() {
    echo ""
    echo "============================================================"
    echo "  VERIFICATION"
    echo "============================================================"

    echo ""
    echo "--- Image layers (size) ---"
    docker image ls "${IMAGE}"

    echo ""
    echo "--- Container status ---"
    docker ps --filter "name=${CONTAINER}" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Networks}}"

    echo ""
    echo "--- Network membership ---"
    docker inspect "${CONTAINER}" \
        --format 'Networks: {{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'

    echo ""
    echo "--- Running user ---"
    docker inspect "${IMAGE}" --format 'Image USER: {{.Config.User}}'

    echo ""
    echo "--- Go toolchain absent in final image ---"
    docker run --rm --entrypoint sh "${IMAGE}" \
        -c "which go 2>/dev/null && echo 'FAIL: go found' || echo 'PASS: go not found'"

    echo ""
    echo "--- Binary and config present ---"
    docker run --rm --entrypoint sh "${IMAGE}" \
        -c "ls -lh /app/"

    echo ""
    echo "--- Container logs (first 5 lines) ---"
    docker logs "${CONTAINER}" 2>&1 | head -5
}

# --------------------------------------------------
# Summary
# --------------------------------------------------
function print_summary() {
    echo ""
    echo "============================================================"
    echo "  SOLUTION COMPLETE"
    echo "============================================================"
    echo ""
    echo "  Dockerfile — 2 stages:"
    echo "    Stage 1 (builder): golang:1.21-alpine"
    echo "      - go mod download (cached layer)"
    echo "      - CGO_ENABLED=0 GOOS=linux go build -o pulse-agent ."
    echo ""
    echo "    Stage 2 (final):   alpine:3.19"
    echo "      - addgroup/adduser pulse (non-root)"
    echo "      - COPY --from=builder /build/pulse-agent /app/pulse-agent"
    echo "      - COPY config.yaml /app/config.yaml"
    echo "      - USER pulse"
    echo "      - CMD [\"/app/pulse-agent\"]"
    echo ""
    echo "  Image:     pulse-agent:latest"
    echo "  Container: pulse-agent (running)"
    echo "  Network:   novapulse-net (bridge)"
    echo "  User:      pulse (non-root)"
    echo ""
    echo "  What was wrong with the original Dockerfile:"
    echo "    - Single stage — shipped entire Go toolchain"
    echo "    - Missing CGO_ENABLED=0 GOOS=linux"
    echo "    - config.yaml never copied into image"
    echo "    - No non-root user"
    echo "    - Container started on default bridge, not novapulse-net"
    echo "============================================================"
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "============================================================"
    echo "  NOVAPULSE DOCKER LAB — APPLYING SOLUTION"
    echo "============================================================"
    echo ""

    echo "[1/4] Writing correct Dockerfile..."
    write_dockerfile

    echo ""
    echo "[2/4] Cleaning up previous build artifacts..."
    cleanup

    echo ""
    echo "[3/4] Building image..."
    build_image

    echo ""
    echo "[4/4] Running container on novapulse-net..."
    run_container

    verify
    print_summary
}

main