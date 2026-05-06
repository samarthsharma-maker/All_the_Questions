#!/bin/bash
# setup-netpol-lab.sh
# Creates the broken ClearLedger network policy environment.
# Run as: bash setup-netpol-lab.sh

set -euo pipefail

BASE_DIR="/home/user/clearledger-lab"
NAMESPACE="clearledger-prod"
MONITORING_NS="monitoring"

mkdir -p "${BASE_DIR}"

# --------------------------------------------------
# Namespaces
# --------------------------------------------------
function create_namespaces() {
    cat > "${BASE_DIR}/namespaces.yaml" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: clearledger-prod
  labels:
    environment: production
    team: platform
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    purpose: monitoring
EOF
    kubectl apply -f "${BASE_DIR}/namespaces.yaml"
}

# --------------------------------------------------
# Deployments — all use nginx:alpine on small resource
# footprints so they schedule on single-node lab clusters.
# --------------------------------------------------
function create_deployments() {
    cat > "${BASE_DIR}/deployments.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: clearledger-prod
  labels:
    app: api-gateway
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: api-gateway
        image: nginx:alpine
        ports:
        - containerPort: 8080
        - containerPort: 9090
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payroll-worker
  namespace: clearledger-prod
  labels:
    app: payroll-worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payroll-worker
  template:
    metadata:
      labels:
        app: payroll-worker
    spec:
      containers:
      - name: payroll-worker
        image: nginx:alpine
        ports:
        - containerPort: 8080
        - containerPort: 9090
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tax-service
  namespace: clearledger-prod
  labels:
    app: tax-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tax-service
  template:
    metadata:
      labels:
        app: tax-service
    spec:
      containers:
      - name: tax-service
        image: nginx:alpine
        ports:
        - containerPort: 8443
        - containerPort: 9090
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ledger-db-proxy
  namespace: clearledger-prod
  labels:
    app: ledger-db-proxy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ledger-db-proxy
  template:
    metadata:
      labels:
        app: ledger-db-proxy
    spec:
      containers:
      - name: ledger-db-proxy
        image: nginx:alpine
        ports:
        - containerPort: 5432
        - containerPort: 9090
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin-toolbox
  namespace: clearledger-prod
  labels:
    app: admin-toolbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: admin-toolbox
  template:
    metadata:
      labels:
        app: admin-toolbox
    spec:
      containers:
      - name: admin-toolbox
        image: busybox:latest
        command: ["sh", "-c", "while true; do sleep 30; done"]
        resources:
          requests:
            cpu: 20m
            memory: 32Mi
          limits:
            cpu: 50m
            memory: 64Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: busybox:latest
        command: ["sh", "-c", "while true; do sleep 30; done"]
        resources:
          requests:
            cpu: 20m
            memory: 32Mi
          limits:
            cpu: 50m
            memory: 64Mi
EOF
    kubectl apply -f "${BASE_DIR}/deployments.yaml"
}

# --------------------------------------------------
# Services
# --------------------------------------------------
function create_services() {
    cat > "${BASE_DIR}/services.yaml" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: clearledger-prod
spec:
  selector:
    app: api-gateway
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  - name: metrics
    port: 9090
    targetPort: 9090
---
apiVersion: v1
kind: Service
metadata:
  name: payroll-worker
  namespace: clearledger-prod
spec:
  selector:
    app: payroll-worker
  ports:
  - name: http
    port: 8080
    targetPort: 8080
  - name: metrics
    port: 9090
    targetPort: 9090
---
apiVersion: v1
kind: Service
metadata:
  name: tax-service
  namespace: clearledger-prod
spec:
  selector:
    app: tax-service
  ports:
  - name: https
    port: 8443
    targetPort: 8443
  - name: metrics
    port: 9090
    targetPort: 9090
---
apiVersion: v1
kind: Service
metadata:
  name: ledger-db-proxy
  namespace: clearledger-prod
spec:
  selector:
    app: ledger-db-proxy
  ports:
  - name: postgres
    port: 5432
    targetPort: 5432
  - name: metrics
    port: 9090
    targetPort: 9090
EOF
    kubectl apply -f "${BASE_DIR}/services.yaml"
}

# --------------------------------------------------
# NetworkPolicies (BROKEN)
#
# BUG 1 — allow-api-gateway-ingress
#   Has a podSelector in the from rule that restricts ingress
#   to only pods labelled app: payroll-worker.
#   api-gateway is the public entry point — from must be empty.
#
# BUG 2 — allow-payroll-worker-ingress
#   namespaceSelector for the Prometheus rule uses the wrong label:
#   team: monitoring  (does not exist on the monitoring namespace)
#   Should be: purpose: monitoring
#
# BUG 3 — allow-tax-service-ingress
#   The from rule for payroll-worker uses two separate list items
#   (OR logic) instead of a single item with both selectors
#   (AND logic). This lets any pod in clearledger-prod reach
#   tax-service, not just payroll-worker.
#
# BUG 4 — allow-ledger-db-proxy-ingress
#   Missing admin-toolbox break-glass ingress rule entirely.
#
# BUG 5 — allow-egress-dns
#   podSelector is scoped to app: api-gateway instead of {}.
#   Only api-gateway gets DNS egress; all other pods cannot
#   resolve service names.
#
# BUG 6 — allow-egress-dns
#   namespaceSelector uses kubernetes.io/metadata.name: dns-system
#   which does not exist. Should be kube-system.
# --------------------------------------------------
function create_broken_netpols() {
    cat > "${BASE_DIR}/network-policies.yaml" <<'EOF'
# ---- api-gateway ----
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-gateway-ingress
  namespace: clearledger-prod
spec:
  podSelector:
    matchLabels:
      app: api-gateway
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: payroll-worker
    ports:
    - protocol: TCP
      port: 8080
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: monitoring
    ports:
    - protocol: TCP
      port: 9090
  - from:
    - podSelector:
        matchLabels:
          app: admin-toolbox
---
# ---- payroll-worker ----
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-payroll-worker-ingress
  namespace: clearledger-prod
spec:
  podSelector:
    matchLabels:
      app: payroll-worker
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          app: clearledger-prod
      podSelector:
        matchLabels:
          app: api-gateway
    ports:
    - protocol: TCP
      port: 8080
  - from:
    - namespaceSelector:
        matchLabels:
          team: monitoring
    ports:
    - protocol: TCP
      port: 9090
  - from:
    - podSelector:
        matchLabels:
          app: admin-toolbox
---
# ---- tax-service ----
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-tax-service-ingress
  namespace: clearledger-prod
spec:
  podSelector:
    matchLabels:
      app: tax-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: production
    - podSelector:
        matchLabels:
          app: payroll-worker
    ports:
    - protocol: TCP
      port: 8443
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: monitoring
    ports:
    - protocol: TCP
      port: 9090
  - from:
    - podSelector:
        matchLabels:
          app: admin-toolbox
---
# ---- ledger-db-proxy ----
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ledger-db-proxy-ingress
  namespace: clearledger-prod
spec:
  podSelector:
    matchLabels:
      app: ledger-db-proxy
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: production
      podSelector:
        matchLabels:
          app: tax-service
    ports:
    - protocol: TCP
      port: 5432
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: monitoring
    ports:
    - protocol: TCP
      port: 9090
---
# ---- egress DNS ----
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-dns
  namespace: clearledger-prod
spec:
  podSelector:
    matchLabels:
      app: api-gateway
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: dns-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF
    kubectl apply -f "${BASE_DIR}/network-policies.yaml"
}

# --------------------------------------------------
# Wait for rollouts
# --------------------------------------------------
function wait_for_rollouts() {
    echo ""
    echo "Waiting for deployments..."
    for dep in api-gateway payroll-worker tax-service ledger-db-proxy admin-toolbox; do
        kubectl rollout status deployment/"${dep}" \
            -n clearledger-prod --timeout=90s || true
    done
    kubectl rollout status deployment/prometheus \
        -n monitoring --timeout=90s || true
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "Setting up ClearLedger Network Policy Lab..."
    echo ""

    echo "[1/4] Creating namespaces..."
    create_namespaces

    echo "[2/4] Creating deployments and services..."
    create_deployments
    create_services

    echo "[3/4] Applying broken NetworkPolicies..."
    create_broken_netpols

    echo "[4/4] Waiting for rollouts..."
    wait_for_rollouts

    chown -R user:user "${BASE_DIR}" 2>/dev/null || true

    echo ""
    echo "============================================================"
    echo "  CLEARLEDGER NETWORK POLICY LAB — ENVIRONMENT READY"
    echo "============================================================"
    echo ""
    echo "  Namespace:  clearledger-prod"
    echo "  Namespace:  monitoring  (label: purpose=monitoring)"
    echo ""
    echo "  Services:   api-gateway, payroll-worker,"
    echo "              tax-service, ledger-db-proxy"
    echo ""
    echo "  NetworkPolicies:"
    echo "    allow-api-gateway-ingress"
    echo "    allow-payroll-worker-ingress"
    echo "    allow-tax-service-ingress"
    echo "    allow-ledger-db-proxy-ingress"
    echo "    allow-egress-dns"
    echo ""
    echo "  There are 6 bugs across these policies."
    echo "  Find and fix them all."
    echo ""
    echo "  Useful commands:"
    echo "    kubectl get netpol -n clearledger-prod"
    echo "    kubectl describe netpol <name> -n clearledger-prod"
    echo "    kubectl get namespace monitoring --show-labels"
    echo "    kubectl get namespace kube-system --show-labels"
    echo "============================================================"
}

main

chown -R user:user "${BASE_DIR}"