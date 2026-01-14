#!/bin/bash
# setup-workload-engine-deployment.sh
# Run as a user who has write permission to /home/user (or adjust path/user as needed)

set -euo pipefail

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/batch-engine.yaml"

echo "Creating/updating ${TARGET_FILE} ..."

mkdir -p "${TARGET_DIR}"

cat > "${TARGET_FILE}" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: workload-engine
  namespace: production
  labels:
    app: workload-engine
    team: analytics
spec:
  replicas: 3
  selector:
    matchLabels:
      app: workload-engine
  template:
    metadata:
      labels:
        app: workload-engine
        environment: production
    spec:
      serviceAccountName: workload-engine-sa
      containers:
      - name: workload-engine
        image: cloudscale/workload-engine:v1.9.3
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: ENGINE_THREADS
          value: "6"
        - name: LOG_LEVEL
          value: "info"
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "400m"
            memory: "1Gi"
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 20
          periodSeconds: 10
EOF

chown user:user "${TARGET_FILE}" 2>/dev/null || true
echo "Deployment manifest written to ${TARGET_FILE}"
echo "You can now apply it with:"
echo "  kubectl apply -f ${TARGET_FILE}"
