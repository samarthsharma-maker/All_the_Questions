#!/bin/bash
set -euo pipefail

BASE_DIR="/home/user/cloudbank-lab"
NAMESPACE="cloudbank-prod"

NS_FILE="${BASE_DIR}/namespace.yaml"
DEPLOY_FILE="${BASE_DIR}/postgres-deployment.yaml"

function create_base_directory() {
    mkdir -p "${BASE_DIR}"
}

function create_namespace_yaml() {
    cat > "${NS_FILE}" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: cloudbank-prod
  labels:
    environment: production
    team: platform
EOF
}

function create_broken_deployment_yaml() {
    cat > "${DEPLOY_FILE}" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-db
  namespace: cloudbank-prod
  labels:
    app: postgres
    tier: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
        tier: database
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
          name: postgres
        
        env:
        - name: POSTGRES_DB
          value: cloudbank
        - name: POSTGRES_USER
          value: bankadmin
        - name: POSTGRES_PASSWORD
          value: SecureBank2024!
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        
        # PROBLEM: Using emptyDir - data is lost on pod restart!
        # emptyDir is ephemeral storage that gets deleted when pod is removed
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
      
      volumes:
      - name: postgres-storage
        emptyDir: {}  # EPHEMERAL - DATA WILL BE LOST!
EOF
}


function finalize_lab_setup() {
    chown -R user:user "${BASE_DIR}" 2>/dev/null || true

    echo
    echo "=========================================="
    echo "CLOUDBANK DATABASE CRISIS"
    echo "=========================================="
    echo
    echo "Lab manifests created:"
    echo "  ${NS_FILE}"
    echo "  ${DEPLOY_FILE}"
    echo
    echo "Apply the lab with:"
    echo "  kubectl apply -f ${BASE_DIR}"
    echo
    echo "=========================================="
    echo "CRITICAL ISSUE:"
    echo "=========================================="
    echo
    echo "The PostgreSQL database is using emptyDir volume!"
    echo
    echo "Impact:"
    echo "  - All customer data LOST when pod restarts"
    echo "  - All transactions LOST on pod deletion"
    echo "  - No data persistence across deployments"
    echo "  - Database starts empty after every restart"
    echo
    echo "Why it's broken:"
    echo "  emptyDir = ephemeral storage (temporary)"
    echo "  Data deleted when pod is removed from node"
    echo "  Not suitable for stateful applications like databases"
    echo
    echo "=========================================="
    echo "LEARNER TASKS:"
    echo "=========================================="
    echo
    echo "You must migrate to persistent storage:"
    echo
    echo "1. Create PersistentVolumeClaim (PVC)"
    echo "   - Name: postgres-pvc"
    echo "   - Namespace: cloudbank-prod"
    echo "   - Storage: 5Gi"
    echo "   - AccessMode: ReadWriteOnce"
    echo "   - StorageClass: standard (or default)"
    echo
    echo "2. Update Deployment to use PVC"
    echo "   - Replace emptyDir with persistentVolumeClaim"
    echo "   - Reference the PVC name: postgres-pvc"
    echo "   - Keep same mountPath: /var/lib/postgresql/data"
    echo
    echo "3. Verify data persistence"
    echo "   - Write test data to database"
    echo "   - Delete the pod (simulate crash)"
    echo "   - Verify data still exists after pod restart"
    echo
    echo "Expected outcome:"
    echo "  ✓ PVC created and bound to PV"
    echo "  ✓ Deployment uses PVC instead of emptyDir"
    echo "  ✓ Pod mounts persistent volume"
    echo "  ✓ Database data survives pod restarts"
    echo "  ✓ Customer data is safe and persistent"
    echo
    echo "=========================================="
}

function main() {
    create_base_directory
    create_namespace_yaml
    create_broken_deployment_yaml
    finalize_lab_setup
}

main