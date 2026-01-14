#!/usr/bin/env bash
# solution-data-processor.sh

set -euo pipefail

BASE_DIR="$HOME/data-processor-solution"
NAMESPACE="techflow-prod"
SERVICE_ACCOUNT="data-processor-sa"

NS_FILE="${BASE_DIR}/namespace.yaml"
SA_FILE="${BASE_DIR}/serviceaccount.yaml"
CM_FILE="${BASE_DIR}/data-processor-configmap.yaml"
DEPLOY_FILE="${BASE_DIR}/data-processor-deployment.yaml"

mkdir -p "$BASE_DIR"

# -------------------------------
# Namespace
# -------------------------------
cat > "$NS_FILE" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
EOF

# -------------------------------
# ServiceAccount
# -------------------------------
cat > "$SA_FILE" <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SERVICE_ACCOUNT}
  namespace: ${NAMESPACE}
EOF

# -------------------------------
# ConfigMap
# -------------------------------
cat > "$CM_FILE" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: data-processor-config
  namespace: production
data:
  processor.conf: |
    PROCESSING_THREADS=4
    LOG_LEVEL=INFO
EOF

# -------------------------------
# Deployment (FIXED)
# -------------------------------
cat > "$DEPLOY_FILE" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-processor
  namespace: production
  labels:
    app: data-processor
spec:
  replicas: 3
  selector:
    matchLabels:
      app: data-processor
  template:
    metadata:
      labels:
        app: data-processor
    spec:
      serviceAccountName: data-processor-sa
      containers:
      - name: data-processor
        image: nginx:alpine
        env:
          - name: JAVA_OPTS
            value: "-Xmx512m -Xms256m"
          - name: PROCESSING_THREADS
            value: "4"
          - name: DATABASE_URL
            value: "postgres://payments-db.${NAMESPACE}.svc.cluster.local:5432/payments"
          - name: SERVICE_NAME
            value: "data-processor"
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "250m"
            memory: "256Mi"
        volumeMounts:
        - name: config
          mountPath: /etc/config
      volumes:
      - name: config
        configMap:
          name: data-processor-config
EOF

# -------------------------------
# Apply
# -------------------------------
kubectl apply -f "$NS_FILE"
kubectl apply -f "$SA_FILE"
kubectl apply -f "$CM_FILE"
kubectl apply -f "$DEPLOY_FILE"

# -------------------------------
# Verify rollout
# -------------------------------
kubectl rollout status deployment/data-processor -n production
kubectl get pods -n production
