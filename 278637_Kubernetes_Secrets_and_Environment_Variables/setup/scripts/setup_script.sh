#!/bin/bash

set -euo pipefail

BASE_DIR="/home/user/healthsync-lab"
NAMESPACE="healthsync-prod"

NS_FILE="${BASE_DIR}/namespace.yaml"
DEPLOY_FILE="${BASE_DIR}/patient-api-deployment.yaml"

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
  name: healthsync-prod
  labels:
    environment: production
    compliance: hipaa
EOF
}

# --------------------------------------------------
# Deployment Manifest (INTENTIONALLY INSECURE)
# Contains hardcoded database password - SECURITY VIOLATION
# --------------------------------------------------
function create_insecure_deployment_yaml() {
    cat > "${DEPLOY_FILE}" <<'EOF'
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
        # Non-sensitive configuration - these are fine
        - name: DB_HOST
          value: postgres-primary.healthsync-prod.svc.cluster.local
        
        - name: DB_NAME
          value: patient_records
        
        - name: DB_USER
          value: healthsync_app
        
        # SECURITY VIOLATION: Password is hardcoded in plain text!
        # This violates HIPAA compliance and security best practices
        - name: DB_PASSWORD
          value: H3alth$ync2024!Secure
        
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
# Permissions & Instructions
# --------------------------------------------------
function finalize_lab_setup() {
    chown -R user:user "${BASE_DIR}" 2>/dev/null || true

    echo
    echo "=========================================="
    echo "SECURITY AUDIT ALERT!"
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
    echo "COMPLIANCE VIOLATION DETECTED:"
    echo "=========================================="
    echo
    echo "The deployment contains a HARDCODED database password!"
    echo "This violates:"
    echo "  - HIPAA compliance requirements"
    echo "  - Security best practices"
    echo "  - Company security policies"
    echo
    echo "Learner tasks:"
    echo "  1. Create Secret 'patient-db-secret' with DB_PASSWORD"
    echo "  2. Update deployment to use secretKeyRef (not hardcoded value)"
    echo "  3. Verify pods restart successfully"
    echo "  4. Confirm password is no longer visible in deployment manifest"
    echo
    echo "Expected Secret:"
    echo "  Name: patient-db-secret"
    echo "  Namespace: healthsync-prod"
    echo "  Key: DB_PASSWORD"
    echo "  Value: H3alth\$ync2024!Secure"
    echo
    echo "=========================================="
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    create_base_directory
    create_namespace_yaml
    create_insecure_deployment_yaml
    finalize_lab_setup
}

main