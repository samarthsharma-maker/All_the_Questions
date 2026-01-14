#!/bin/bash
# setup-misconfigured-ports.sh
# Creates multiple Kubernetes manifests containing intentionally incorrect
# container ports for validation-based lab exercises.

set -euo pipefail

TARGET_DIR="/home/user"

echo "Preparing misconfigured Kubernetes manifests in ${TARGET_DIR} ..."
mkdir -p "${TARGET_DIR}"

###########################################
# Deployment: service-a (wrong port 8080)
###########################################
cat << 'EOF' > "${TARGET_DIR}/service-a-deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-a
  labels:
    app: service-a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: service-a
  template:
    metadata:
      labels:
        app: service-a
    spec:
      containers:
      - name: service-a
        image: novaedge/service-a:v1.0.0
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
EOF
chown user:user "${TARGET_DIR}/service-a-deployment.yaml" 2>/dev/null || true


###########################################
# ReplicaSet: service-b (wrong port 3001)
###########################################
cat << 'EOF' > "${TARGET_DIR}/service-b-replicaset.yaml"
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: service-b
  labels:
    app: service-b
spec:
  replicas: 3
  selector:
    matchLabels:
      app: service-b
  template:
    metadata:
      labels:
        app: service-b
    spec:
      containers:
      - name: service-b
        image: novaedge/service-b:v3.4
        ports:
        - containerPort: 3001
        livenessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 10
EOF
chown user:user "${TARGET_DIR}/service-b-replicaset.yaml" 2>/dev/null || true


###########################################
# Pod: service-c (wrong port 7000)
###########################################
cat << 'EOF' > "${TARGET_DIR}/service-c-pod.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: service-c
  labels:
    app: service-c
spec:
  containers:
  - name: service-c
    image: novaedge/service-c:v2.1
    ports:
    - containerPort: 7000
    env:
    - name: SERVICE_MODE
      value: "processor"
EOF
chown user:user "${TARGET_DIR}/service-c-pod.yaml" 2>/dev/null || true


###########################################
# Deployment: service-d (mixed incorrect ports)
###########################################
cat << 'EOF' > "${TARGET_DIR}/service-d-deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-d
  labels:
    app: service-d
spec:
  replicas: 1
  selector:
    matchLabels:
      app: service-d
  template:
    metadata:
      labels:
        app: service-d
    spec:
      containers:
      - name: service-d
        image: novaedge/service-d:v0.9
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: 3001
          initialDelaySeconds: 4
        livenessProbe:
          httpGet:
            path: /live
            port: 8080
          initialDelaySeconds: 6
EOF
chown user:user "${TARGET_DIR}/service-d-deployment.yaml" 2>/dev/null || true


echo "All misconfigured manifests created successfully in ${TARGET_DIR}."
exit 0
