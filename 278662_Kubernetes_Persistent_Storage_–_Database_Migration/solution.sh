#!/bin/bash
# solution-pvc-lab.sh
# Migrates database from ephemeral emptyDir to persistent storage
# Creates PVC and updates deployment

set -euo pipefail

BASE_DIR="$HOME/cloudbank-solution"
NAMESPACE="cloudbank-prod"

NS_FILE="${BASE_DIR}/namespace.yaml"
PVC_FILE="${BASE_DIR}/postgres-pvc.yaml"
DEPLOY_FILE="${BASE_DIR}/postgres-deployment-fixed.yaml"

mkdir -p "$BASE_DIR"

# --------------------------------------------------
# Namespace
# --------------------------------------------------
function create_namespace_yaml() {
    cat > "$NS_FILE" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: cloudbank-prod
  labels:
    environment: production
    team: platform
EOF
}

# --------------------------------------------------
# PersistentVolume (Manual - if no dynamic provisioning)
# --------------------------------------------------
function create_manual_pv_if_needed() {
    # Check if there's a default storage class or dynamic provisioner
    if kubectl get storageclass 2>/dev/null | grep -q "(default)"; then
        echo "Dynamic provisioning available, skipping manual PV creation."
        return 0
    fi
    
    echo "No default StorageClass found. Creating manual PersistentVolume..."
    
    cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv
  labels:
    type: local
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data/postgres"
    type: DirectoryOrCreate
  persistentVolumeReclaimPolicy: Retain
EOF
    
    echo "Manual PersistentVolume created."
}

# --------------------------------------------------
# PersistentVolumeClaim (NEW)
# --------------------------------------------------
function create_pvc_yaml() {
    cat > "$PVC_FILE" <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: cloudbank-prod
  labels:
    app: postgres
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  # storageClassName: standard  # Omitted to use cluster default or manual PV
EOF
}

# --------------------------------------------------
# Deployment (FIXED - USING PVC)
# --------------------------------------------------
function create_fixed_deployment_yaml() {
    cat > "$DEPLOY_FILE" <<'EOF'
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
        
        # FIXED: Now using PersistentVolumeClaim
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
        persistentVolumeClaim:
          claimName: postgres-pvc  # Using PVC instead of emptyDir
EOF
}

# --------------------------------------------------
# Ensure Namespace Exists
# --------------------------------------------------
function ensure_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo "Creating namespace $NAMESPACE..."
        kubectl apply -f "$NS_FILE"
    else
        echo "Namespace $NAMESPACE already exists."
    fi
}

# --------------------------------------------------
# Apply Resources
# --------------------------------------------------
function apply_resources() {
    echo ""
    echo "Applying PersistentVolumeClaim..."
    kubectl apply -f "$PVC_FILE"
    
    echo ""
    echo "Waiting for PVC to be bound (max 30 seconds)..."
    for i in {1..30}; do
        PVC_STATUS=$(kubectl get pvc postgres-pvc -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [ "$PVC_STATUS" == "Bound" ]; then
            echo "PVC is bound!"
            break
        fi
        echo "Waiting for PVC to bind... ($i/30)"
        sleep 1
    done
    
    echo ""
    echo "Applying updated Deployment with persistent storage..."
    kubectl apply -f "$DEPLOY_FILE"
}

# --------------------------------------------------
# Verify Deployment
# --------------------------------------------------
function verify_deployment() {
    echo ""
    echo "Waiting for deployment rollout..."
    kubectl rollout status deployment/postgres-db -n "$NAMESPACE" --timeout=120s
    
    echo ""
    echo "Verifying pod is running..."
    kubectl get pods -n "$NAMESPACE" -l app=postgres
}

# --------------------------------------------------
# Test Data Persistence
# --------------------------------------------------
function test_data_persistence() {
    echo ""
    echo "=========================================="
    echo "DATA PERSISTENCE TEST"
    echo "=========================================="
    
    # Get pod name
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$POD_NAME" ]; then
        echo "ERROR: No postgres pod found"
        return 1
    fi
    
    echo ""
    echo "1. Creating test database table with customer data..."
    kubectl exec -it "$POD_NAME" -n "$NAMESPACE" -- psql -U bankadmin -d cloudbank -c "
    CREATE TABLE IF NOT EXISTS customers (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100),
        account_number VARCHAR(50),
        balance DECIMAL(10,2),
        created_at TIMESTAMP DEFAULT NOW()
    );"
    
    echo ""
    echo "2. Inserting test customer records..."
    kubectl exec -it "$POD_NAME" -n "$NAMESPACE" -- psql -U bankadmin -d cloudbank -c "
    INSERT INTO customers (name, account_number, balance) VALUES
    ('Alice Johnson', 'ACC001', 15000.50),
    ('Bob Smith', 'ACC002', 25000.75),
    ('Carol White', 'ACC003', 10500.00);"
    
    echo ""
    echo "3. Verifying data was inserted..."
    kubectl exec -it "$POD_NAME" -n "$NAMESPACE" -- psql -U bankadmin -d cloudbank -c "
    SELECT * FROM customers ORDER BY id;"
    
    echo ""
    echo "4. Simulating pod crash (deleting pod)..."
    kubectl delete pod "$POD_NAME" -n "$NAMESPACE"
    
    echo ""
    echo "5. Waiting for new pod to start..."
    sleep 10
    kubectl wait --for=condition=ready pod -l app=postgres -n "$NAMESPACE" --timeout=60s
    
    # Get new pod name
    NEW_POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[0].metadata.name}')
    
    echo ""
    echo "6. Verifying data SURVIVED pod restart..."
    echo "   New pod: $NEW_POD_NAME"
    kubectl exec -it "$NEW_POD_NAME" -n "$NAMESPACE" -- psql -U bankadmin -d cloudbank -c "
    SELECT COUNT(*) as customer_count FROM customers;"
    
    echo ""
    kubectl exec -it "$NEW_POD_NAME" -n "$NAMESPACE" -- psql -U bankadmin -d cloudbank -c "
    SELECT * FROM customers ORDER BY id;"
    
    echo ""
    echo "=========================================="
    echo "✓ DATA PERSISTENCE VERIFIED!"
    echo "=========================================="
    echo "Customer data survived pod restart."
    echo "Persistent storage is working correctly."
    echo "=========================================="
}

# --------------------------------------------------
# Show Summary
# --------------------------------------------------
function show_summary() {
    echo ""
    echo "=========================================="
    echo "STORAGE MIGRATION SUMMARY"
    echo "=========================================="
    echo ""
    echo "Before (BROKEN):"
    echo "  ✗ emptyDir volume (ephemeral)"
    echo "  ✗ Data lost on pod restart"
    echo "  ✗ No persistence"
    echo ""
    echo "After (FIXED):"
    echo "  ✓ PersistentVolumeClaim created"
    echo "  ✓ PVC bound to PersistentVolume"
    echo "  ✓ Deployment uses PVC"
    echo "  ✓ Data persists across pod restarts"
    echo "  ✓ Database is now production-ready"
    echo ""
    echo "PVC Details:"
    kubectl get pvc postgres-pvc -n "$NAMESPACE"
    echo ""
    echo "PV Details:"
    PV_NAME=$(kubectl get pvc postgres-pvc -n "$NAMESPACE" -o jsonpath='{.spec.volumeName}')
    if [ -n "$PV_NAME" ]; then
        kubectl get pv "$PV_NAME"
    fi
    echo ""
    echo "=========================================="
    echo "DATABASE STORAGE SECURED"
    echo "=========================================="
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "=========================================="
    echo "MIGRATING TO PERSISTENT STORAGE"
    echo "=========================================="
    echo ""
    echo "Creating solution files in: $BASE_DIR"
    echo ""
    
    create_namespace_yaml
    create_pvc_yaml
    create_fixed_deployment_yaml
    
    echo "Solution files created:"
    echo "  $NS_FILE"
    echo "  $PVC_FILE"
    echo "  $DEPLOY_FILE"
    echo ""
    
    ensure_namespace
    create_manual_pv_if_needed
    apply_resources
    verify_deployment
    test_data_persistence
    show_summary
}

main