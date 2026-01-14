#!/bin/bash
# setup-goapp-dockerfile.sh
# Run as a user who has write permission to /home/user (or adjust path/user as needed)

set -euo pipefail

TARGET_DIR="/home/user/goapp"
TARGET_FILE="${TARGET_DIR}/Dockerfile"

echo "Creating/updating ${TARGET_FILE} ..."

mkdir -p "${TARGET_DIR}"

cat > "${TARGET_FILE}" <<'EOF'
# ----------- BUILD STAGE (BROKEN) -----------
FROM golang:1.22-****** AS build

ENV CGO_ENABLED=0 \
    GOOS:linux \
    GOARCH:amd64

WORKDIR /src

*** apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -o server main.go



# ----------- RUNTIME STAGE (CORRECT) -----------
FROM alpine:3.19

RUN apk add --no-cache ca-certificates

WORKDIR /app

# Copy only the compiled static binary
COPY --from=build /src/server ./server

# Ensure the binary is executable
RUN chmod +x ./server

# Do not run as root
USER 1000:1000

# Correct environment setting
ENV APP_ENV=production

# Expose service port
EXPOSE 8080

# Correct startup command
CMD ["./server"]
EOF

chown user:user "${TARGET_FILE}" 2>/dev/null || true
echo "Dockerfile written to ${TARGET_FILE}"
echo "NOTE: Docker commands are disabled in this environment."
echo "Only edit the Dockerfile — do NOT run 'docker build' or 'docker run'."
