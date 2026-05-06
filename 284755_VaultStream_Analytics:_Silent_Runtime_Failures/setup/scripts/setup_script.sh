#!/bin/bash
# setup-configmap-lab.sh
# Creates the broken VaultStream ConfigMap/Secret environment.
# Run as: bash setup-configmap-lab.sh

set -euo pipefail

BASE_DIR="/home/user/vaultstream-lab"
NAMESPACE="vaultstream-prod"

mkdir -p "${BASE_DIR}"

# --------------------------------------------------
# Namespace
# --------------------------------------------------
function create_namespace() {
    cat > "${BASE_DIR}/namespace.yaml" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: vaultstream-prod
  labels:
    environment: production
    team: data-platform
EOF
    kubectl apply -f "${BASE_DIR}/namespace.yaml"
}

# --------------------------------------------------
# ConfigMaps
#
# BUG 3: worker-config is MISSING the key "broker_address".
#         The key present is "broker_host" — a different name.
#         transform-worker references "broker_address" with
#         optional: false so the pod will crash with
#         CreateContainerConfigError.
#
# BUG 9: pipeline-feature-flags is MISSING the key "enable_audit_log".
#         The key present is "audit_logging_enabled".
#         audit-logger references "enable_audit_log" with
#         optional: false so the pod will crash with
#         CreateContainerConfigError.
# --------------------------------------------------
function create_configmaps() {
    cat > "${BASE_DIR}/configmaps.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingestor-config
  namespace: vaultstream-prod
data:
  db_host: "postgres.vaultstream-prod.svc.cluster.local"
  db_port: "5432"
  db_name: "events_db"
  log_level: "info"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: worker-config
  namespace: vaultstream-prod
data:
  broker_host: "kafka.vaultstream-prod.svc.cluster.local:9092"
  worker_threads: "4"
  batch_size: "500"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: dispatcher-config
  namespace: vaultstream-prod
data:
  routing_table: |
    client_a=topic_a
    client_b=topic_b
    client_c=topic_c
  retry_limit: "3"
  timeout_ms: "5000"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: pipeline-feature-flags
  namespace: vaultstream-prod
data:
  audit_logging_enabled: "true"
  dry_run: "false"
  metrics_enabled: "true"
EOF
    kubectl apply -f "${BASE_DIR}/configmaps.yaml"
}

# --------------------------------------------------
# Secrets
#
# BUG 1: db-credentials "password" is double-base64-encoded.
#         Plaintext:     Str0ng!Pass#2024
#         Single base64: U3RyMG5nIVBhc3MjMjAyNA==
#         Stored value below is base64("U3RyMG5nIVBhc3MjMjAyNA==")
#         Pods receive the base64 string as the password — silent.
#
# BUG 6+7: broker-tls-secret is in vaultstream-staging, not
#           vaultstream-prod. route-dispatcher will be stuck in
#           ContainerCreating with a MountVolume.SetUp failed event.
# --------------------------------------------------
function create_secrets() {
    cat > "${BASE_DIR}/db-credentials.yaml" <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: vaultstream-prod
type: Opaque
data:
  username: dmF1bHRzdHJlYW0tYXBw
  # BUG 1: Double-encoded. Decoded value is "U3RyMG5nIVBhc3MjMjAyNA=="
  # (itself a base64 string) instead of "Str0ng!Pass#2024"
  password: VTNSeU1HNW5JVkJoYzNNak1qQXlOQT09
EOF
    kubectl apply -f "${BASE_DIR}/db-credentials.yaml"

    cat > "${BASE_DIR}/audit-signing-key.yaml" <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: audit-signing-key
  namespace: vaultstream-prod
type: Opaque
data:
  signing_key: c2lnbmluZ19zZWNyZXRfa2V5XzIwMjQ=
EOF
    kubectl apply -f "${BASE_DIR}/audit-signing-key.yaml"
    kubectl create namespace vaultstream-staging --dry-run=client -o yaml \
        | kubectl apply -f -

    cat > "${BASE_DIR}/broker-tls-secret.yaml" <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: broker-tls-secret
  namespace: vaultstream-staging
type: Opaque
data:
  tls.crt: dGxzLWNlcnQtcGxhY2Vob2xkZXI=
  tls.key: dGxzLWtleS1wbGFjZWhvbGRlcg==
EOF
    kubectl apply -f "${BASE_DIR}/broker-tls-secret.yaml"
}

# --------------------------------------------------
# Deployments (BROKEN)
#
# BUG 2: event-ingestor — DB_PASSWORD references key "passwd"
#         which does not exist. optional: false → CreateContainerConfigError.
#
# BUG 3 (Deployment side): transform-worker references key "broker_address"
#         with optional: false. Key absent from worker-config → crash.
#
# BUG 4: transform-worker — correct key reference but env var is named
#         "BROKER_HOST" instead of "BROKER_ADDRESS". This bug only manifests
#         AFTER Bug 3 is fixed — the pod starts but the app reads empty string.
#
# BUG 5: route-dispatcher — dispatcher-config-vol mounted at "/etc/config"
#         instead of "/etc/dispatcher". Pod runs, app silently gets no config.
#
# BUG 8: audit-logger — SIGNING_KEY references key "key" which does not
#         exist in audit-signing-key. optional: false → CreateContainerConfigError.
#
# BUG 10: audit-logger — enable_audit_log injected as "AUDIT_LOG_ENABLED"
#          instead of "ENABLE_AUDIT_LOG". This bug only manifests AFTER
#          Bug 9 is fixed — pod starts but app reads empty string.
# --------------------------------------------------
function create_deployments() {
    cat > "${BASE_DIR}/deployments.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: event-ingestor
  namespace: vaultstream-prod
  labels:
    app: event-ingestor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: event-ingestor
  template:
    metadata:
      labels:
        app: event-ingestor
    spec:
      containers:
      - name: event-ingestor
        image: busybox:latest
        command: ["sh", "-c", "while true; do sleep 30; done"]
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: ingestor-config
              key: db_host
              optional: false
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: ingestor-config
              key: db_port
              optional: false
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
              optional: false

        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: passwd
              optional: false
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: transform-worker
  namespace: vaultstream-prod
  labels:
    app: transform-worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: transform-worker
  template:
    metadata:
      labels:
        app: transform-worker
    spec:
      containers:
      - name: transform-worker
        image: busybox:latest
        command: ["sh", "-c", "while true; do sleep 30; done"]
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        env:
        - name: WORKER_THREADS
          valueFrom:
            configMapKeyRef:
              name: worker-config
              key: worker_threads
              optional: false
        - name: BROKER_HOST
          valueFrom:
            configMapKeyRef:
              name: worker-config
              key: broker_address
              optional: false
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: route-dispatcher
  namespace: vaultstream-prod
  labels:
    app: route-dispatcher
spec:
  replicas: 1
  selector:
    matchLabels:
      app: route-dispatcher
  template:
    metadata:
      labels:
        app: route-dispatcher
    spec:
      containers:
      - name: route-dispatcher
        image: busybox:latest
        command: ["sh", "-c", "while true; do sleep 30; done"]
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        volumeMounts:
        - name: dispatcher-config-vol
          mountPath: /etc/config
        - name: broker-tls-vol
          mountPath: /etc/tls
      volumes:
      - name: dispatcher-config-vol
        configMap:
          name: dispatcher-config
      - name: broker-tls-vol
        secret:
          secretName: broker-tls-secret
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audit-logger
  namespace: vaultstream-prod
  labels:
    app: audit-logger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: audit-logger
  template:
    metadata:
      labels:
        app: audit-logger
    spec:
      containers:
      - name: audit-logger
        image: busybox:latest
        command: ["sh", "-c", "while true; do sleep 30; done"]
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
        env:
        - name: SIGNING_KEY
          valueFrom:
            secretKeyRef:
              name: audit-signing-key
              key: key
              optional: false
        - name: AUDIT_LOG_ENABLED
          valueFrom:
            configMapKeyRef:
              name: pipeline-feature-flags
              key: enable_audit_log
              optional: false
EOF
    kubectl apply -f "${BASE_DIR}/deployments.yaml"
}

# --------------------------------------------------
# Wait — non-fatal since several pods will be stuck
# --------------------------------------------------
function wait_for_rollouts() {
    echo ""
    echo "Waiting for deployments (some will be stuck — this is expected)..."
    for dep in event-ingestor transform-worker route-dispatcher audit-logger; do
        kubectl rollout status deployment/"${dep}" \
            -n "${NAMESPACE}" --timeout=30s || true
    done
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "Setting up VaultStream ConfigMap/Secret Lab..."
    echo ""

    echo "[1/4] Creating namespace..."
    create_namespace

    echo "[2/4] Creating ConfigMaps..."
    create_configmaps

    echo "[3/4] Creating Secrets..."
    create_secrets

    echo "[4/4] Creating Deployments..."
    create_deployments

    wait_for_rollouts
    chown -R user:user "${BASE_DIR}" 2>/dev/null || true
    echo ""
    echo "============================================================"
    echo "  VAULTSTREAM CONFIGMAP/SECRET LAB — ENVIRONMENT READY"
    echo "============================================================"
    echo ""
    echo "  Expected pod states after setup:"
    echo "    event-ingestor   → CreateContainerConfigError (Bug 2)"
    echo "    transform-worker → CreateContainerConfigError (Bug 3)"
    echo "    route-dispatcher → ContainerCreating           (Bug 6/7)"
    echo "    audit-logger     → CreateContainerConfigError  (Bug 8/9)"
    echo ""
    echo "  6 bugs total span: Secrets, ConfigMaps, and Deployment specs."
    echo "  Some bugs only surface after earlier ones are fixed."
    echo ""
    echo "  Useful commands:"
    echo "    kubectl get pods -n vaultstream-prod"
    echo "    kubectl describe pod <name> -n vaultstream-prod"
    echo "    kubectl get configmap <name> -n vaultstream-prod -o yaml"
    echo "    kubectl get secret <name> -n vaultstream-prod -o yaml"
    echo "    kubectl get secret broker-tls-secret --all-namespaces"
    echo "============================================================"
}

main