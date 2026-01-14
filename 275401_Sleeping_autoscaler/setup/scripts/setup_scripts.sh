#!/bin/bash

set -euo pipefail

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/stream-mapper.yaml"

echo "Creating incorrect HPA manifest at ${TARGET_FILE} ..."

mkdir -p "${TARGET_DIR}"

cat <<EOF > "${TARGET_FILE}"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: stream-mapper-hpa
spec:
  minReplicas: 1
  maxReplicas: 2
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 10
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: stream-mapper
EOF

echo "Incorrect HPA manifest created."

# Safe permission change
chown user:user "${TARGET_FILE}" 2>/dev/null || true
echo "HPA manifest created at ${TARGET_FILE}"