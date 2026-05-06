#!/bin/bash


set -euo pipefail

TARGET_DIR="/home/user"
PROJECT_DIR="${TARGET_DIR}/clearbank-lab"

print_status() { echo -e " $1"; }

print_status "Checking Docker prerequisites"

if ! command -v docker &> /dev/null; then
  echo "Docker is not installed. Please install Docker."
  exit 1
fi

if ! docker info &> /dev/null; then
  echo "Docker daemon is not running."
  exit 1
fi

print_status "Docker is installed and running"

print_status "Cleaning up any previous lab resources"

docker rm -f api db 2>/dev/null || true
docker network rm clearbank-net 2>/dev/null || true
docker rmi clearbank-api 2>/dev/null || true

print_status "Creating project directory at ${PROJECT_DIR}"
mkdir -p "${PROJECT_DIR}"

print_status "Creating go.mod"

cat << 'EOF' > "${PROJECT_DIR}/go.mod"
module clearbank.io/account-summary-api

go 1.21
EOF

print_status "Creating Go API source (main.go)"

cat << 'EOF' > "${PROJECT_DIR}/main.go"
package main

import (
	"fmt"
	"net"
	"net/http"
	"os"
	"time"
)

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, `{"status":"ok","service":"account-summary-api"}`)
}

func pingDBHandler(w http.ResponseWriter, r *http.Request) {
	host := getEnv("DB_HOST", "db")
	port := getEnv("DB_PORT", "5432")
	addr := net.JoinHostPort(host, port)

	conn, err := net.DialTimeout("tcp", addr, 3*time.Second)
	if err != nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		fmt.Fprintf(w,
			`{"status":"error","message":"cannot reach db","address":"%s","error":"%s"}`,
			addr, err.Error(),
		)
		return
	}
	conn.Close()

	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w,
		`{"status":"ok","message":"database is reachable","address":"%s"}`,
		addr,
	)
}

func infoHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w,
		`{"DB_HOST":"%s","DB_PORT":"%s","DB_USER":"%s","DB_NAME":"%s"}`,
		getEnv("DB_HOST", ""),
		getEnv("DB_PORT", ""),
		getEnv("DB_USER", ""),
		getEnv("DB_NAME", ""),
	)
}

func getEnv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok {
		return v
	}
	return fallback
}

func main() {
	port := getEnv("APP_PORT", "8080")

	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/ping-db", pingDBHandler)
	mux.HandleFunc("/info", infoHandler)

	fmt.Printf("[clearbank-api] Starting on port %s\n", port)

	if err := http.ListenAndServe(":"+port, mux); err != nil {
		fmt.Fprintf(os.Stderr, "fatal: %v\n", err)
		os.Exit(1)
	}
}
EOF

print_status "Creating Dockerfile (do not modify)"

cat << 'EOF' > "${PROJECT_DIR}/Dockerfile"
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod .
COPY main.go .

RUN go build -o account-summary-api .

FROM alpine:3.19

WORKDIR /app

COPY --from=builder /app/account-summary-api .

EXPOSE 8080

CMD ["./account-summary-api"]
EOF

print_status "Creating README.md"

cat << 'EOF' > "${PROJECT_DIR}/README.md"
# ClearBank Digital Banking – Docker Networking Challenge

You are given a pre-built Go API and Dockerfile.

Do NOT modify the source code or Dockerfile.

Your task is to:

1. Create a custom Docker bridge network named `clearbank-net`
2. Run a PostgreSQL container named `db` on that network
3. Build the API image as `clearbank-api`
4. Run the API container named `api` on the same network
5. Verify connectivity using the provided endpoints

### Verification
- curl http://localhost:8080/health
- curl http://localhost:8080/ping-db

EOF

chown -R user:user "${TARGET_DIR}" 2>/dev/null || true

print_status "Setup complete"
print_status "Project created at: ${PROJECT_DIR}"
print_status "You may now begin the Docker networking challenge"
print_status "Setup script finished."

