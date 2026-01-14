#!/bin/bash

set -euo pipefail

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/orion-panel-ingress.yaml"

echo "Creating/updating ${TARGET_FILE} ..."

mkdir -p "${TARGET_DIR}"

cat <<EOF > "${TARGET_FILE}"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orion-panel-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"
spec:
  rules:
    - host: orion.internal.company.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: orion-panel-service
                port:
                  number: 8080
EOF

# Safe permission change
chown user:user "${TARGET_FILE}" 2>/dev/null || true

echo "Ingress manifest created at ${TARGET_FILE}"
