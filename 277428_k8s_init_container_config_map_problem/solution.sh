#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Variables
# -----------------------------
NAMESPACE="techflow-prod"
CONFIGMAP="gateway-config"
DEPLOYMENT="payment-gateway"

# -----------------------------
# Pre-flight checks
# -----------------------------
command -v kubectl >/dev/null || {
  echo "kubectl not found"
  exit 1
}

kubectl cluster-info >/dev/null || {
  echo "Kubernetes cluster not reachable"
  exit 1
}

# -----------------------------
# Create Namespace
# -----------------------------
echo "==> Creating namespace"
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || \
kubectl create namespace "$NAMESPACE"

# -----------------------------
# Create ConfigMap (VALID)
# -----------------------------
echo "==> Creating ConfigMap with required configuration"
kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${CONFIGMAP}
data:
  gateway.conf: |
    SERVICE_NAME=payment-gateway
    SERVICE_VERSION=3.2.1
    DATABASE_URL=postgres://payments-db.techflow-prod.svc.cluster.local:5432/payments
    REDIS_URL=redis://cache.techflow-prod.svc.cluster.local:6379
    MAX_CONNECTIONS=100
    TIMEOUT_SECONDS=30
EOF

# -----------------------------
# Create Deployment
# -----------------------------
echo "==> Creating Deployment with init container validation"
kubectl apply -n "$NAMESPACE" -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-gateway
  labels:
    app: payment-gateway
    tier: critical
    team: payments
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-gateway
  template:
    metadata:
      labels:
        app: payment-gateway
        tier: critical
        team: payments
    spec:
      initContainers:
      - name: config-guardian
        image: busybox:1.36
        command:
          - sh
          - -c
          - |
            set -e

            echo "[INFO] Validating configuration file"
            FILE="/config/gateway.conf"

            if [ ! -f "$FILE" ]; then
              echo "[ERROR] Configuration file missing"
              exit 1
            fi

            REQUIRED_KEYS="SERVICE_NAME SERVICE_VERSION DATABASE_URL REDIS_URL MAX_CONNECTIONS TIMEOUT_SECONDS"

            for key in $REQUIRED_KEYS; do
              if ! grep -q "^$key=" "$FILE"; then
                echo "[ERROR] Missing required key: $key"
                exit 1
              fi
              echo "[OK] Found key: $key"
            done

            echo "[SUCCESS] Configuration validation completed"
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "50m"
            memory: "64Mi"
        volumeMounts:
        - name: config-volume
          mountPath: /config
      containers:
      - name: gateway
        image: nginx:alpine
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        volumeMounts:
        - name: config-volume
          mountPath: /etc/techflow
      volumes:
      - name: config-volume
        configMap:
          name: gateway-config
          items:
          - key: gateway.conf
            path: gateway.conf
EOF

# -----------------------------
# Wait for rollout
# -----------------------------
echo "==> Waiting for pods to become ready"
kubectl rollout status deployment/$DEPLOYMENT -n "$NAMESPACE"

# -----------------------------
# Verify init container logs
# -----------------------------
echo "==> Verifying init container logs"
POD=$(kubectl get pods -n "$NAMESPACE" -l app=payment-gateway -o jsonpath='{.items[0].metadata.name}')
kubectl logs "$POD" -n "$NAMESPACE" -c config-guardian

# -----------------------------
# Verify config inside app container
# -----------------------------
echo "==> Verifying configuration access in main container"
kubectl exec -n "$NAMESPACE" "$POD" -c gateway -- cat /etc/techflow/gateway.conf

# -----------------------------
# FAILURE TEST A
# -----------------------------
echo "==> FAILURE TEST A: Delete ConfigMap and scale deployment"
kubectl delete configmap "$CONFIGMAP" -n "$NAMESPACE"
kubectl scale deployment "$DEPLOYMENT" -n "$NAMESPACE" --replicas=4

sleep 5
kubectl get pods -n "$NAMESPACE"

# -----------------------------
# FAILURE TEST B
# -----------------------------
echo "==> FAILURE TEST B: Recreate ConfigMap missing DATABASE_URL"
kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${CONFIGMAP}
data:
  gateway.conf: |
    SERVICE_NAME=payment-gateway
    SERVICE_VERSION=3.2.1
    REDIS_URL=redis://cache.techflow-prod.svc.cluster.local:6379
    MAX_CONNECTIONS=100
    TIMEOUT_SECONDS=30
EOF

kubectl rollout restart deployment "$DEPLOYMENT" -n "$NAMESPACE"

sleep 5
kubectl get pods -n "$NAMESPACE"

echo "==> Script completed"
