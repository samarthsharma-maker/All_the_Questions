#!/bin/bash
# setup-misconfigured-app-labels.sh
# Generates four manifests with only 1–2 small misconfigurations each.

set -euo pipefail
TARGET_DIR="/home/user"

mkdir -p "${TARGET_DIR}"

CORRECT_APP="nova-app"

echo "Creating minimally misconfigured manifests in ${TARGET_DIR} ..."

###########################################
# Deployment (ONE error: template label mismatch)
###########################################
cat << EOF > "${TARGET_DIR}/component-deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nova-app-deploy
  labels:
    app: ${CORRECT_APP}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${CORRECT_APP}
  template:
    metadata:
      labels:
        app: nova-app-wrong-label
    spec:
      containers:
      - name: nova-app
        image: nginx:alpine
EOF
chown user:user "${TARGET_DIR}/component-deployment.yaml" 2>/dev/null || true


###########################################
# ReplicaSet (ONE error: selector mismatch)
###########################################
cat << EOF > "${TARGET_DIR}/component-replicaset.yaml"
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nova-app-rs
  labels:
    app: ${CORRECT_APP}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nova-app-mismatch
  template:
    metadata:
      labels:
        app: ${CORRECT_APP}
    spec:
      containers:
      - name: nova-app
        image: nginx:alpine
EOF
chown user:user "${TARGET_DIR}/component-replicaset.yaml" 2>/dev/null || true


###########################################
# Pod (ONE error: wrong app label)
###########################################
cat << EOF > "${TARGET_DIR}/component-pod.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: nova-app-pod
  labels:
    app: wrong-label
spec:
  containers:
  - name: nova-app
    image: nginx:alpine
EOF
chown user:user "${TARGET_DIR}/component-pod.yaml" 2>/dev/null || true


###########################################
# Service (ONE error: wrong selector)
###########################################
cat << EOF > "${TARGET_DIR}/component-service.yaml"
apiVersion: v1
kind: Service
metadata:
  name: nova-app-service
  labels:
    app: ${CORRECT_APP}
spec:
  selector:
    app: wrong-selector
  ports:
  - port: 80
    targetPort: 80
EOF
chown user:user "${TARGET_DIR}/component-service.yaml" 2>/dev/null || true

echo "Manifests created successfully with minimal misconfigurations."
exit 0
