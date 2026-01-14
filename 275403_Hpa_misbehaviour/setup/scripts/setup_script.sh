#!/bin/bash

set -euo pipefail

TARGET_FILE="/home/user/event-normalizer-hpa.yaml"
TARGET_DIR="/home/user"

echo "Creating misconfigured HPA manifest at ${TARGET_FILE} ..."

mkdir -p "${TARGET_DIR}"

cat <<EOF > "${TARGET_FILE}"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: event-normalizer-hpa
spec:
  minReplicas: 25
  maxReplicas: 30
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: event-normalizer
EOF

echo "Setup complete."

chown user:user "${TARGET_FILE}" 2>/dev/null || true
echo "HPA manifest created at ${TARGET_FILE}"