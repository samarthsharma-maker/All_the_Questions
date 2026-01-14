#!/bin/bash

set -euo pipefail

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/orion-reports-ingress.yaml"

echo "Creating/updating ${TARGET_FILE} ..."

mkdir -p "${TARGET_DIR}"

cat <<EOF > "${TARGET_FILE}"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orion-reports-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: reports.internal.company.com
      http:
        paths:
          - path: /
            pathType: ImplementationSpecific
            backend:
              service:
                name: orion-reports-service
                port:
                  number: 9000
EOF

# Safe permission change
chown user:user "${TARGET_FILE}" 2>/dev/null || true

echo "Ingress manifest created at ${TARGET_FILE}"
