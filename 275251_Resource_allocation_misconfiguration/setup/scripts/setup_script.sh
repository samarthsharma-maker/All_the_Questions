#!/bin/bash
# setup-data-processor-deployment.sh
# Run as a user who has write permission to /home/user (or adjust the path/user as needed)

set -euo pipefail

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/data-processor-deployment.yaml"

echo "Creating/updating ${TARGET_FILE} ..."

mkdir -p "${TARGET_DIR}"

cat > "${TARGET_FILE}" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-processor
  namespace: production
  labels:
    app: data-processor
    environment: production
    team: analytics
spec:
  replicas: 3
  selector:
    matchLabels:
      app: data-processor
  template:
    metadata:
      labels:
        app: data-processor
        environment: production
    spec:
      containers:
      - name: data-processor
        image: cloudscale/data-processor:v2.4.1
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 9090
          name: metrics
          protocol: TCP
        env:
        - name: JAVA_OPTS
          value: "-Xmx3g -Xms512m"
        - name: PROCESSING_THREADS
          value: "4"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: url
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 20
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        volumeMounts:
        - name: config
          mountPath: /etc/config
        - name: cache
          mountPath: /var/cache/processor
      volumes:
      - name: config
        configMap:
          name: data-processor-config
      - name: cache
        emptyDir:
          sizeLimit: 10Gi
      serviceAccountName: data-processor-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
EOF

chown user:user "${TARGET_FILE}" 2>/dev/null || true
echo "Deployment manifest written to ${TARGET_FILE}"
echo "You can now apply it with:"
echo "  kubectl apply -f ${TARGET_FILE}"
