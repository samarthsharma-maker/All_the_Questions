#!/bin/bash
# setup-payment-gateway-lab.sh
# Creates Kubernetes YAML manifests with intentional misconfigurations
# Each responsibility is isolated into a function

set -euo pipefail

BASE_DIR="/home/user/techflow-lab"
NAMESPACE="techflow-prod"

NS_FILE="${BASE_DIR}/namespace.yaml"
CM_FILE="${BASE_DIR}/gateway-configmap.yaml"
DEPLOY_FILE="${BASE_DIR}/payment-gateway-deployment.yaml"

# --------------------------------------------------
# Utilities
# --------------------------------------------------
function create_base_directory() {
    mkdir -p "${BASE_DIR}"
}

# --------------------------------------------------
# Namespace Manifest
# --------------------------------------------------
function create_namespace_yaml() {
    cat > "${NS_FILE}" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: techflow-prod
EOF
}

# --------------------------------------------------
# ConfigMap Manifest (INTENTIONALLY BROKEN)
# Missing DATABASE_URL
# --------------------------------------------------
function create_broken_configmap_yaml() {
    cat > "${CM_FILE}" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: gateway-config
  namespace: techflow-prod
data:
  gateway.conf: |
    SERVICE_NAME=payment-gateway
    SERVICE_VERSION=3.2.1
    REDIS_URL=redis://cache.techflow-prod.svc.cluster.local:6379
    MAX_CONNECTIONS=100
    TIMEOUT_SECONDS=30
EOF
}

# --------------------------------------------------
# Deployment Manifest (MULTIPLE MISCONFIGURATIONS)
# --------------------------------------------------
function create_broken_deployment_yaml() {
    cat > "${DEPLOY_FILE}" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-gateway
  namespace: techflow-prod
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
      # Misconfiguration: nodeSelector matches no nodes
      nodeSelector:
        workload: payments

      # Misconfiguration: toleration without matching taint
      tolerations:
      - key: "workload"
        operator: "Equal"
        value: "payments"
        effect: "NoSchedule"

      initContainers:
      - name: config-guardian
        image: busybox:1.36
        command:
          - sh
          - -c
          - |
            set -e
            FILE="/config/gateway.conf"

            if [ ! -f "$FILE" ]; then
              echo "Config file missing"
              exit 1
            fi

            REQUIRED_KEYS="SERVICE_NAME SERVICE_VERSION DATABASE_URL REDIS_URL MAX_CONNECTIONS TIMEOUT_SECONDS"
            for key in $REQUIRED_KEYS; do
              if ! grep -q "^$key=" "$FILE"; then
                echo "Missing required key: $key"
                exit 1
              fi
            done
        volumeMounts:
        - name: config-volume
          mountPath: /config

      containers:
      - name: gateway
        # Misconfiguration: invalid image tag
        image: nginx:alpinee

        ports:
        - containerPort: 8080

        resources:
          # Misconfiguration: requests exceed limits
          requests:
            cpu: "600m"
            memory: "512Mi"
          limits:
            cpu: "500m"
            memory: "256Mi"

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
}

# --------------------------------------------------
# Permissions & Instructions
# --------------------------------------------------
function finalize_lab_setup() {
    chown -R user:user "${BASE_DIR}" 2>/dev/null || true

    echo
    echo "Lab manifests created:"
    echo "  ${NS_FILE}"
    echo "  ${CM_FILE}"
    echo "  ${DEPLOY_FILE}"
    echo
    echo "Apply the lab with:"
    echo "  kubectl apply -f ${BASE_DIR}"
    echo
    echo "Learner tasks:"
    echo "  - Fix missing DATABASE_URL in ConfigMap"
    echo "  - Resolve nodeSelector scheduling issue"
    echo "  - Fix container image name"
    echo "  - Correct resource requests/limits"
    echo "  - Ensure init container validation passes"
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    create_base_directory
    create_namespace_yaml
    create_broken_configmap_yaml
    create_broken_deployment_yaml
    finalize_lab_setup
}

main
