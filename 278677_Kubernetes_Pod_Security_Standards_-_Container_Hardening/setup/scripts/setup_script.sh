#!/bin/bash

set -euo pipefail

BASE_DIR="/home/user/medisecure-lab"
NAMESPACE_PROD="medisecure-prod"
NAMESPACE_DEV="medisecure-dev"

NS_PROD_FILE="${BASE_DIR}/namespace-prod.yaml"
NS_DEV_FILE="${BASE_DIR}/namespace-dev.yaml"
INSECURE_DEPLOY_FILE="${BASE_DIR}/patient-data-processor-insecure.yaml"

function create_base_directory() {  mkdir -p "${BASE_DIR}"; }

function create_namespace_yamls() {
    cat > "${NS_PROD_FILE}" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: medisecure-prod
  labels:
    environment: production
    compliance: hipaa
EOF

    cat > "${NS_DEV_FILE}" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: medisecure-dev
  labels:
    environment: development
EOF
}

function create_insecure_deployment() {
    cat > "${INSECURE_DEPLOY_FILE}" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: patient-data-processor
  namespace: medisecure-prod
  labels:
    app: patient-data-processor
    tier: backend
  annotations:
    description: "Processes patient medical records - CRITICAL HIPAA DATA"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: patient-data-processor
  template:
    metadata:
      labels:
        app: patient-data-processor
        tier: backend
    spec:
      containers:
      - name: processor
        image: nginx:alpine
        ports:
        - containerPort: 80
          name: http
        
        # SECURITY VIOLATIONS - HIPAA NON-COMPLIANT!
        # Running as root with privileged mode
        securityContext:
          privileged: true              # CRITICAL: Full host access!
          runAsUser: 0                  # Running as root!
          allowPrivilegeEscalation: true # Can gain more privileges!
          # Missing: runAsNonRoot
          # Missing: capabilities drop
          # Missing: readOnlyRootFilesystem
          # Missing: seccompProfile
        
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: patient-data-processor
  namespace: medisecure-prod
  labels:
    app: patient-data-processor
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    name: http
  selector:
    app: patient-data-processor
EOF
}

function apply_resources() {
    echo ""
    echo "Creating namespaces..."
    kubectl apply -f "${NS_PROD_FILE}"
    kubectl apply -f "${NS_DEV_FILE}"
    
    echo ""
    echo "Deploying INSECURE patient data processor..."
    kubectl apply -f "${INSECURE_DEPLOY_FILE}"
    
    echo ""
    echo "Waiting for deployment..."
    kubectl rollout status deployment/patient-data-processor -n "${NAMESPACE_PROD}" --timeout=60s || true
}

function demonstrate_security_violations() {
    echo ""
    echo "=========================================="
    echo "SECURITY AUDIT - VIOLATIONS DETECTED"
    echo "=========================================="
    echo ""
    
    POD=$(kubectl get pods -n "${NAMESPACE_PROD}" -l app=patient-data-processor -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$POD" ]; then
        echo "Warning: No pod found yet"
        return
    fi
    
    echo "Checking container user..."
    kubectl exec "$POD" -n "${NAMESPACE_PROD}" -- id 2>/dev/null || echo "Pod not ready yet"
    
    echo ""
    echo "Checking privileged mode..."
    PRIVILEGED=$(kubectl get pod "$POD" -n "${NAMESPACE_PROD}" -o jsonpath='{.spec.containers[0].securityContext.privileged}')
    echo "  Privileged: $PRIVILEGED"
    
    echo ""
    echo "Checking security context..."
    kubectl get pod "$POD" -n "${NAMESPACE_PROD}" -o jsonpath='{.spec.containers[0].securityContext}' | jq '.' || echo "{}"
    
    echo ""
    echo "=========================================="
    echo "⚠️  CRITICAL HIPAA VIOLATIONS FOUND!"
    echo "=========================================="
    echo ""
    echo "Violations detected:"
    echo "  ❌ Container running as root (UID 0)"
    echo "  ❌ Privileged mode enabled"
    echo "  ❌ Privilege escalation allowed"
    echo "  ❌ No capabilities restrictions"
    echo "  ❌ Root filesystem is writable"
    echo "  ❌ No seccomp profile"
    echo "  ❌ No Pod Security Admission enforcement"
    echo ""
    echo "HIPAA Impact:"
    echo "  - Container can escape to host"
    echo "  - Can access all patient data on node"
    echo "  - Can compromise other containers"
    echo "  - Violates §164.312(a)(1) Access Control"
    echo "  - Potential fines: \$1.5M per violation"
    echo ""
}

function show_instructions() {
    chown -R user:user "${BASE_DIR}" 2>/dev/null || true

    echo ""
    echo "=========================================="
    echo "MEDISECURE POD SECURITY LAB"
    echo "=========================================="
    echo ""
    echo "Lab files created in: ${BASE_DIR}"
    echo ""
    echo "=========================================="
    echo "CURRENT INSECURE STATE:"
    echo "=========================================="
    echo ""
    echo "The patient-data-processor deployment has CRITICAL security flaws:"
    echo ""
    echo "1. Running as root (UID 0)"
    echo "   - Violates principle of least privilege"
    echo "   - HIPAA violation"
    echo ""
    echo "2. Privileged mode enabled"
    echo "   - Full access to host system"
    echo "   - Can escape container"
    echo "   - Can access all patient data"
    echo ""
    echo "3. Allows privilege escalation"
    echo "   - Can gain additional permissions"
    echo "   - Security bypass possible"
    echo ""
    echo "4. No capability restrictions"
    echo "   - Has all Linux capabilities"
    echo "   - Excessive permissions"
    echo ""
    echo "5. Writable root filesystem"
    echo "   - Can be modified/tampered"
    echo "   - Malware can persist"
    echo ""
    echo "6. No seccomp profile"
    echo "   - Unrestricted system calls"
    echo ""
    echo "7. No Pod Security Admission"
    echo "   - No enforcement of security standards"
    echo ""
    echo "=========================================="
    echo "YOUR MISSION:"
    echo "=========================================="
    echo ""
    echo "HARDEN THE DEPLOYMENT TO MEET 'RESTRICTED' PROFILE:"
    echo ""
    echo "1. ENABLE POD SECURITY ADMISSION"
    echo "   Label namespace with:"
    echo "   - pod-security.kubernetes.io/enforce=restricted"
    echo "   - pod-security.kubernetes.io/warn=restricted"
    echo "   - pod-security.kubernetes.io/audit=restricted"
    echo ""
    echo "2. RUN AS NON-ROOT USER"
    echo "   Pod securityContext:"
    echo "     runAsNonRoot: true"
    echo "     runAsUser: 1000"
    echo "     runAsGroup: 3000"
    echo "     fsGroup: 2000"
    echo ""
    echo "3. DISABLE PRIVILEGED MODE"
    echo "   Container securityContext:"
    echo "     privileged: false (or remove it)"
    echo ""
    echo "4. DISABLE PRIVILEGE ESCALATION"
    echo "   Container securityContext:"
    echo "     allowPrivilegeEscalation: false"
    echo ""
    echo "5. DROP ALL CAPABILITIES"
    echo "   Container securityContext:"
    echo "     capabilities:"
    echo "       drop:"
    echo "       - ALL"
    echo ""
    echo "6. READ-ONLY ROOT FILESYSTEM"
    echo "   Container securityContext:"
    echo "     readOnlyRootFilesystem: true"
    echo "   Add emptyDir volumes for /tmp, /var/cache/nginx, /var/run"
    echo ""
    echo "7. SET SECCOMP PROFILE"
    echo "   Pod securityContext:"
    echo "     seccompProfile:"
    echo "       type: RuntimeDefault"
    echo ""
    echo "=========================================="
    echo "VERIFICATION:"
    echo "=========================================="
    echo ""
    echo "After fixing, verify:"
    echo "  kubectl exec <pod> -n medisecure-prod -- id"
    echo "  (should show uid=1000, NOT uid=0)"
    echo ""
    echo "  kubectl get pod <pod> -n medisecure-prod -o jsonpath='{.spec.containers[0].securityContext}'"
    echo "  (should show all security settings)"
    echo ""
    echo "Test that insecure pods are rejected:"
    echo "  kubectl apply -f <insecure-pod> --dry-run=server"
    echo "  (should be forbidden by Pod Security Admission)"
    echo ""
    echo "=========================================="
    echo "COMPLIANCE:"
    echo "=========================================="
    echo ""
    echo "Meeting Restricted profile ensures:"
    echo "  ✓ HIPAA §164.312(a)(1) compliance"
    echo "  ✓ SOC 2 CC6.1 compliance"
    echo "  ✓ PCI-DSS Requirement 2 compliance"
    echo "  ✓ Container isolation"
    echo "  ✓ Principle of least privilege"
    echo "  ✓ Defense in depth"
    echo ""
    echo "=========================================="
}

function main() {
    create_base_directory
    create_namespace_yamls
    create_insecure_deployment
    apply_resources
    demonstrate_security_violations
    show_instructions
}

main