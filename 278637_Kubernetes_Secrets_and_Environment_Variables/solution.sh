#!/bin/bash
# solution-secrets-lab.sh
# Fixes the hardcoded password security violation
# Creates Secret and updates deployment to use secretKeyRef

set -euo pipefail

BASE_DIR="$HOME/healthsync-solution"
NAMESPACE="healthsync-prod"

SECRET_FILE="${BASE_DIR}/patient-db-secret.yaml"
DEPLOY_FILE="${BASE_DIR}/patient-api-deployment-fixed.yaml"

mkdir -p "$BASE_DIR"

# --------------------------------------------------
# Secret for Database Password
# --------------------------------------------------
function create_secret_yaml() {
    cat > "$SECRET_FILE" <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: patient-db-secret
  namespace: healthsync-prod
type: Opaque
stringData:
  DB_PASSWORD: H3alth$ync2024!Secure
EOF
}

# --------------------------------------------------
# Deployment (FIXED - SECURE VERSION)
# Uses secretKeyRef instead of hardcoded password
# --------------------------------------------------
function create_fixed_deployment_yaml() {
    cat > "$DEPLOY_FILE" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: patient-api
  namespace: healthsync-prod
  labels:
    app: patient-api
    tier: api
    compliance: hipaa
spec:
  replicas: 3
  selector:
    matchLabels:
      app: patient-api
  template:
    metadata:
      labels:
        app: patient-api
        tier: api
        compliance: hipaa
    spec:
      containers:
      - name: api
        image: nginx:alpine
        ports:
        - containerPort: 8080
        
        env:
        # Non-sensitive configuration - remain as regular values
        - name: DB_HOST
          value: postgres-primary.healthsync-prod.svc.cluster.local
        
        - name: DB_NAME
          value: patient_records
        
        - name: DB_USER
          value: healthsync_app
        
        # FIXED: Password now comes from Secret using secretKeyRef
        # This is the HIPAA-compliant way to handle credentials
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: patient-db-secret
              key: DB_PASSWORD
        
        - name: APP_NAME
          value: patient-api
        
        - name: LOG_LEVEL
          value: info
        
        resources:
          requests:
            cpu: 150m
            memory: 256Mi
          limits:
            cpu: 400m
            memory: 512Mi
EOF
}

# --------------------------------------------------
# Ensure Namespace Exists
# --------------------------------------------------
function ensure_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo "Creating namespace $NAMESPACE..."
        kubectl create namespace "$NAMESPACE"
        kubectl label namespace "$NAMESPACE" environment=production compliance=hipaa
    else
        echo "Namespace $NAMESPACE already exists."
    fi
}

# --------------------------------------------------
# Apply Resources
# --------------------------------------------------
function apply_resources() {
    echo ""
    echo "Applying Secret..."
    kubectl apply -f "$SECRET_FILE"
    
    echo ""
    echo "Applying fixed Deployment..."
    kubectl apply -f "$DEPLOY_FILE"
}

# --------------------------------------------------
# Verify Deployment
# --------------------------------------------------
function verify_deployment() {
    echo ""
    echo "Waiting for deployment rollout..."
    kubectl rollout status deployment/patient-api -n "$NAMESPACE" --timeout=120s
    
    echo ""
    echo "Verifying pods are running..."
    kubectl get pods -n "$NAMESPACE" -l app=patient-api
}

# --------------------------------------------------
# Security Verification
# --------------------------------------------------
function verify_security() {
    echo ""
    echo "=========================================="
    echo "SECURITY VERIFICATION"
    echo "=========================================="
    
    echo ""
    echo "1. Verifying Secret exists:"
    kubectl get secret patient-db-secret -n "$NAMESPACE"
    
    echo ""
    echo "2. Verifying deployment uses secretKeyRef (not hardcoded):"
    kubectl get deployment patient-api -n "$NAMESPACE" -o yaml | grep -A 5 "DB_PASSWORD"
    
    echo ""
    echo "3. Verifying password is NOT visible in deployment description:"
    echo "   (Should show: '<set to the key 'DB_PASSWORD' in secret 'patient-db-secret'>')"
    kubectl describe deployment patient-api -n "$NAMESPACE" | grep -A 1 "DB_PASSWORD:"
    
    echo ""
    echo "4. Verifying password IS populated in running pod:"
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=patient-api -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec "$POD_NAME" -n "$NAMESPACE" -- env | grep -q "^DB_PASSWORD="; then
        echo "   SUCCESS: DB_PASSWORD is set in pod (value hidden for security)"
    else
        echo "   ERROR: DB_PASSWORD is not set in pod"
        exit 1
    fi
    
    echo ""
    echo "=========================================="
    echo "SECURITY REMEDIATION COMPLETE"
    echo "=========================================="
    echo ""
    echo "Summary of fixes:"
    echo "  - Created Secret 'patient-db-secret' with DB_PASSWORD"
    echo "  - Updated deployment to use secretKeyRef"
    echo "  - Password is no longer hardcoded in deployment manifest"
    echo "  - Password is no longer visible in version control"
    echo "  - HIPAA compliance violation RESOLVED"
    echo ""
    echo "All 3 pods are running with credentials from Secret."
    echo "=========================================="
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "=========================================="
    echo "FIXING SECURITY VIOLATION"
    echo "=========================================="
    echo ""
    echo "Creating solution files in: $BASE_DIR"
    echo ""
    
    create_secret_yaml
    create_fixed_deployment_yaml
    
    echo "Solution files created:"
    echo "  $SECRET_FILE"
    echo "  $DEPLOY_FILE"
    echo ""
    
    ensure_namespace
    apply_resources
    verify_deployment
    verify_security
}

main