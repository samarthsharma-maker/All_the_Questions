#!/bin/bash
set -euo pipefail

APP_DIR="/home/user/pulse-agent"
NETWORK="novapulse-net"

mkdir -p "${APP_DIR}"
mkdir -p "${APP_DIR}/tests"
mkdir -p "${APP_DIR}/healthcheck"

function create_source() {
    cat > "${APP_DIR}/go.mod" <<'EOF'
module github.com/novapulse/pulse-agent

go 1.21
EOF

    cat > "${APP_DIR}/main.go" <<'EOF'
package main

import (
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	appEnv := os.Getenv("APP_ENV")
	logLevel := os.Getenv("LOG_LEVEL")
	fmt.Printf("pulse-agent starting [env=%s log=%s]\n", appEnv, logLevel)

	configPath := "/app/config.yaml"
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "ERROR: config file not found at %s\n", configPath)
		os.Exit(1)
	}

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "ok")
	})

	go func() {
		if err := http.ListenAndServe(":8080", nil); err != nil {
			fmt.Fprintf(os.Stderr, "http server error: %v\n", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, syscall.SIGINT)
	<-stop
	fmt.Println("pulse-agent shutting down gracefully.")
}
EOF

    cat > "${APP_DIR}/healthcheck/main.go" <<'EOF'
package main

import (
	"fmt"
	"net/http"
	"os"
)

func main() {
	resp, err := http.Get("http://localhost:8080/health")
	if err != nil {
		fmt.Fprintf(os.Stderr, "healthcheck failed: %v\n", err)
		os.Exit(1)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		fmt.Fprintf(os.Stderr, "healthcheck: unexpected status %d\n", resp.StatusCode)
		os.Exit(1)
	}
	fmt.Println("healthcheck: ok")
}
EOF

    cat > "${APP_DIR}/config.yaml" <<'EOF'
agent:
  name: pulse-agent
  version: "2.0.0"
  collection_interval: 10s
metrics:
  enabled: true
  endpoint: "http://aggregator.novapulse.internal:9090/ingest"
log:
  level: info
  format: json
EOF

    cat > "${APP_DIR}/.env" <<'EOF'
DB_PASSWORD=supersecret_localdev_only
API_KEY=dev-api-key-do-not-ship
EOF

    cat > "${APP_DIR}/tests/main_test.go" <<'EOF'
package main

import "testing"

func TestHealthEndpoint(t *testing.T) {
	t.Log("placeholder test")
}
EOF
}

function create_dockerfile() {
    cat > "${APP_DIR}/Dockerfile" <<'EOF'
# ---- Stage 1: Build ----
FROM golang:1.21-alpine AS builder

ARG BUILD_VERSION
ENV BUILD_VERSION=${BUILD_VERSION}

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

USER pulse

ENTRYPOINT /app/pulse-agent
EOF
}

function create_dockerignore() {
    cat > "${APP_DIR}/.dockerignore" <<'EOF'
Dockerfile
.dockerignore
EOF
}

function main() {
    echo "Setting up NovaPulse Docker Lab v2..."

    echo "[1/6] Creating source files..."
    create_source
    echo "      OK"

    echo "[2/6] Creating Dockerfile..."
    create_dockerfile
    echo "      OK"

    echo "[3/6] Creating .dockerignore..."
    create_dockerignore
    echo "      OK"

    echo "[4/6] Creating network '${NETWORK}'..."
    if docker network inspect "${NETWORK}" &>/dev/null; then
        echo "      Already exists — skipping"
    else
        docker network create \
            --driver bridge \
            --subnet 172.30.0.0/24 \
            --label lab=novapulse \
            "${NETWORK}"
        echo "      OK"
    fi

    echo "[5/6] Building image and starting container..."
    docker rm -f pulse-agent-staging 2>/dev/null || true
    docker rmi -f pulse-agent:v2     2>/dev/null || true

    echo "      Building pulse-agent:v2 (this may take a minute)..."
    docker build \
        --build-arg BUILD_VERSION=2.0.0 \
        -t pulse-agent:v2 \
        "${APP_DIR}"
    echo "      Build OK"

    echo "      Starting pulse-agent-staging..."
    docker run -d \
        --name pulse-agent-staging \
        --network "${NETWORK}" \
        -e APP_ENV=production \
        pulse-agent:v2
    echo "      Container OK — $(docker inspect pulse-agent-staging --format '{{.State.Status}}')"

    echo "[6/6] Fixing file ownership..."
    chown -R user:user "${APP_DIR}"
    echo "      OK — ${APP_DIR} owner: $(stat -c '%U:%G' ${APP_DIR})"

    echo ""
    echo "Ready. Working directory: ${APP_DIR}"
    echo "Container 'pulse-agent-staging' is running on '${NETWORK}'."
}

main