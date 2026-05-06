#!/bin/bash
set -euo pipefail

APP_DIR="/home/user/pulse-agent"
mkdir -p "${APP_DIR}"


function create_go_source() {
    cat > "${APP_DIR}/go.mod" <<'EOF'
module github.com/novapulse/pulse-agent

go 1.21
EOF

    cat > "${APP_DIR}/main.go" <<'EOF'
package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	fmt.Println("NovaPulse pulse-agent starting...")

	configPath := "/app/config.yaml"
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "ERROR: config file not found at %s\n", configPath)
		os.Exit(1)
	}
	fmt.Printf("Config loaded from %s\n", configPath)

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, syscall.SIGINT)

	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			fmt.Println("Collecting metrics...")
		case <-stop:
			fmt.Println("pulse-agent shutting down.")
			return
		}
	}
}
EOF

    cat > "${APP_DIR}/config.yaml" <<'EOF'
agent:
  name: pulse-agent
  version: "1.0.0"
  collection_interval: 10s

metrics:
  enabled: true
  endpoint: "http://aggregator.novapulse.internal:9090/ingest"

log:
  level: info
  format: json
EOF
}

function create_broken_dockerfile() {
    cat > "${APP_DIR}/Dockerfile" <<'EOF'
# Single-stage build — ships entire Go toolchain in the final image
FROM golang:1.21-alpine

WORKDIR /app

# Copy everything including source and module files
COPY . .

# Download dependencies
RUN go mod download

# Build the binary — missing CGO_ENABLED=0 and GOOS=linux
RUN go build -o pulse-agent .

# Config file is never copied — app will exit on startup

# No non-root user created — runs as root

# No WORKDIR set for runtime — paths may be ambiguous

CMD ["./pulse-agent"]
EOF
}

function create_network() {
    if docker network inspect novapulse-net &>/dev/null; then
        echo "  Network 'novapulse-net' already exists — skipping creation"
    else
        docker network create --driver bridge --subnet 172.30.0.0/24 --label lab=novapulse novapulse-net
        echo "  Network 'novapulse-net' created"
    fi
}

# --------------------------------------------------
# Stop and remove any existing pulse-agent container
# from a previous run so the lab starts clean
# --------------------------------------------------
function cleanup_existing_container() {
    if docker ps -a --format '{{.Names}}' | grep -q "^pulse-agent$"; then
        echo "  Removing existing pulse-agent container..."
        docker rm -f pulse-agent
    fi
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "Setting up NovaPulse Docker Lab..."
    echo ""

    echo "[1/4] Creating Go source files..."
    create_go_source

    echo "[2/4] Creating broken Dockerfile..."
    create_broken_dockerfile

    echo "[3/4] Creating bridge network 'novapulse-net'..."
    create_network

    echo "[4/4] Cleaning up any previous container..."
    cleanup_existing_container

    chown -R user:user "${APP_DIR}" 2>/dev/null || true

    echo ""
    echo "============================================================"
    echo "  NOVAPULSE DOCKER LAB — ENVIRONMENT READY"
    echo "============================================================"
    echo ""
    echo "  Working directory: ${APP_DIR}"
    echo ""
    echo "  Files:"
    echo "    main.go       — Go source (do not modify)"
    echo "    go.mod        — Go module file (do not modify)"
    echo "    config.yaml   — Static agent config"
    echo "    Dockerfile    — Rewrite this entirely"
    echo ""
    echo "  Docker network 'novapulse-net' is ready."
    echo ""
    echo "  Your tasks:"
    echo "    1. Rewrite ${APP_DIR}/Dockerfile"
    echo "    2. Build the image as pulse-agent:latest"
    echo "    3. Run a container named pulse-agent on novapulse-net"
    echo ""
    echo "  Useful commands:"
    echo "    docker build -t pulse-agent:latest ${APP_DIR}"
    echo "    docker run -d --name pulse-agent --network novapulse-net pulse-agent:latest"
    echo "    docker inspect pulse-agent"
    echo "    docker network inspect novapulse-net"
    echo "============================================================"
}

main

echo "Creating/updating ${APP_DIR} ..."
chown -r user:user "${APP_DIR}" 2>/dev/null || true