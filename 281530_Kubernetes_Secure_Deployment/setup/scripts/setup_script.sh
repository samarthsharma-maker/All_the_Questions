#!/bin/bash

set -euo pipefail
TARGET_DIR="/home/user"
REPO="k8s-secure-deployment"
BASE_DIR="$TARGET_DIR/${REPO}"
NAMESPACE="secure-deploy-prod"

echo " Setting up Kubernetes Secure Deployment Challenge"
echo "Repo directory: ${BASE_DIR}"
echo "---------------------------------------------------"

mkdir -p "${BASE_DIR}"
cd "${BASE_DIR}"

echo "Ensuring namespace exists: ${NAMESPACE}"
kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"


echo " Creating service.yaml"
cat <<'EOF' > service.yaml
apiVersion: v1
kind: Service
metadata:
  name: microservice-svc
spec:
  type: ClusterIP
  selector:
    app: microservice
  ports:
    - port: 80
      targetPort: 80
EOF


echo " Creating deployment.yaml"
cat <<'EOF' > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: microservice-app
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: microservice
  template:
    metadata:
      labels:
        app: microservice
    spec:
      containers:
        - name: microservice-app
          image: nginx:alpine
          ports:
            - containerPort: 80

          # Liveness probe is present
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
EOF

echo " Creating README.md"
cat <<'EOF' > README.md
# Kubernetes Secure Deployment Challenge

A partial deployment and service already exist in the cluster.

Your task is to:
- Create a ConfigMap and Secret
- Update the existing Deployment to:
  - Mount the ConfigMap
  - Inject environment variables
  - Add a readiness probe
  - Configure resource requests and limits

Do NOT recreate the Deployment or Service.
EOF


echo " Applying Service"
kubectl apply -f service.yaml -n "${NAMESPACE}"

echo " Applying Deployment (incomplete)"
kubectl apply -f deployment.yaml -n "${NAMESPACE}"

# --------------------------------------------------
# Wait for rollout
# --------------------------------------------------
echo " Waiting for deployment rollout"
kubectl rollout status deployment/microservice-app -n "${NAMESPACE}"

echo ""
echo " LAB ENVIRONMENT READY"
echo ""
echo "Files created in: ${BASE_DIR}"
echo "- deployment.yaml (incomplete)"
echo "- service.yaml (complete)"
echo ""
echo "Cluster state:"
echo "- Deployment exists but is missing required components"
echo "- Service is functional"
echo "- No ConfigMap or Secret exists"


chown -R user:user "${BASE_DIR}" 2>/dev/null || true
echo "Setup complete. Please follow the README.md instructions to complete the lab."