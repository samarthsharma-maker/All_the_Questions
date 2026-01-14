#!/bin/bash
# setup-goapp-runtime-dockerfile.sh
# Creates the broken runtime-stage Dockerfile for Sister Question B

set -euo pipefail

TARGET_DIR="/home/user/goapp-runtime"
TARGET_FILE="${TARGET_DIR}/Dockerfile"

echo "Creating/updating ${TARGET_FILE} ..."

mkdir -p "${TARGET_DIR}"

cat > "${TARGET_FILE}" <<'EOF'
# ----------- BUILD STAGE (CORRECT) -----------
FROM golang:1.22-alpine AS build

ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

WORKDIR /src

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o server main.go



# ----------- RUNTIME STAGE (BROKEN) -----------
FROM alpine:3.19

*** apk add --no-cache ca-certificates

WORKDIR /app

COPY --from=build /src/server ./server

RUN chmod 777 ./server

USER 1000:1010

ENV APP_ENV:production

EXPOSE 8000

CMD ["server"]
EOF

chown user:user "${TARGET_FILE}" 2>/dev/null || true
echo "Dockerfile written to ${TARGET_FILE}"
echo "NOTE: Docker commands are disabled. Fix the Dockerfile only."
