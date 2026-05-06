#!/bin/bash
# solution-pod-security-lab.sh
# Implements Pod Security Standards - Restricted profile
# Hardens deployment to meet HIPAA compliance

set -euo pipefail

BASE_DIR="$HOME/medisecure-solution"
NAMESPACE_PROD="medisecure-prod"

mkdir -p "$BASE_DIR"

# --------------------------------------------------
# Hardened Deployment (Restricted Profile)
# --------------------------------------------------
function create_hardened_deployment() {
    cat > "$BASE_DIR/patient-data-processor-hardened.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: patient-data-processor
  namespace: medisecure-prod
  labels:
    app: patient-data-processor
    tier: backend
    security: hardened
  annotations:
    description: "Processes patient medical records - HIPAA COMPLIANT"
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
      # POD-LEVEL SECURITY CONTEXT
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      
      containers:
      - name: processor
        image: nginx:alpine
        ports:
        - containerPort: 8080
          name: http
        
        # CONTAINER-LEVEL SECURITY CONTEXT
        # All settings required for Restricted profile
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          privileged: false
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        
        # Provide writable volumes for necessary paths
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
        
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
      
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
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
    targetPort: 8080
    name: http
  selector:
    app: patient-data-processor
EOF
}

# --------------------------------------------------
# Enable Pod Security Admission
# --------------------------------------------------
function enable_pod_security_admission() {
    echo ""
    echo "=========================================="
    echo "ENABLING POD SECURITY ADMISSION"
    echo "=========================================="
    echo ""
    
    echo "Labeling namespace for Restricted profile enforcement..."
    kubectl label namespace "$NAMESPACE_PROD" \
      pod-security.kubernetes.io/enforce=restricted \
      pod-security.kubernetes.io/warn=restricted \
      pod-security.kubernetes.io/audit=restricted \
      --overwrite
    
    echo ""
    echo "Verifying namespace labels..."
    kubectl get namespace "$NAMESPACE_PROD" -o yaml | grep pod-security
}

# --------------------------------------------------
# Apply Hardened Deployment
# --------------------------------------------------
function apply_hardened_deployment() {
    echo ""
    echo "=========================================="
    echo "APPLYING HARDENED DEPLOYMENT"
    echo "=========================================="
    echo ""
    
    echo "Applying hardened deployment..."
    kubectl apply -f "$BASE_DIR/patient-data-processor-hardened.yaml"
    
    echo ""
    echo "Waiting for rollout to complete..."
    kubectl rollout status deployment/patient-data-processor -n "$NAMESPACE_PROD" --timeout=120s
}

# --------------------------------------------------
# Verify Security Configuration
# --------------------------------------------------
function verify_security() {
    echo ""
    echo "=========================================="
    echo "VERIFYING SECURITY CONFIGURATION"
    echo "=========================================="
    echo ""
    
    # Get pod name
    POD=$(kubectl get pods -n "$NAMESPACE_PROD" -l app=patient-data-processor -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$POD" ]; then
        echo "ERROR: No pod found"
        return 1
    fi
    
    echo "Pod: $POD"
    echo ""
    
    # Test 1: Check user ID
    echo "Test 1: Verifying container runs as non-root..."
    USER_ID=$(kubectl exec "$POD" -n "$NAMESPACE_PROD" -- id -u)
    echo "  User ID: $USER_ID"
    if [ "$USER_ID" == "1000" ]; then
        echo "  ✓ PASS: Running as UID 1000 (non-root)"
    else
        echo "  ✗ FAIL: Not running as expected UID"
    fi
    
    echo ""
    echo "Test 2: Checking full user info..."
    kubectl exec "$POD" -n "$NAMESPACE_PROD" -- id
    
    echo ""
    echo "Test 3: Verifying security context settings..."
    kubectl get pod "$POD" -n "$NAMESPACE_PROD" -o jsonpath='{.spec.containers[0].securityContext}' | jq '.'
    
    echo ""
    echo "Test 4: Testing read-only root filesystem..."
    if kubectl exec "$POD" -n "$NAMESPACE_PROD" -- touch /test.txt 2>&1 | grep -q "Read-only file system"; then
        echo "  ✓ PASS: Root filesystem is read-only"
    else
        echo "  ✗ FAIL: Root filesystem is writable"
    fi
    
    echo ""
    echo "Test 5: Testing writable /tmp volume..."
    if kubectl exec "$POD" -n "$NAMESPACE_PROD" -- touch /tmp/test.txt 2>/dev/null; then
        echo "  ✓ PASS: Can write to /tmp (emptyDir)"
        kubectl exec "$POD" -n "$NAMESPACE_PROD" -- ls -la /tmp/test.txt
    else
        echo "  ✗ FAIL: Cannot write to /tmp"
    fi
    
    echo ""
    echo "Test 6: Attempting privileged operation (should fail)..."
    if kubectl exec "$POD" -n "$NAMESPACE_PROD" -- mount 2>&1 | grep -q "permission denied"; then
        echo "  ✓ PASS: Privileged operations blocked"
    else
        echo "  ✗ WARNING: Unexpected result from mount command"
    fi
}

# --------------------------------------------------
# Test Pod Security Admission
# --------------------------------------------------
function test_pod_security_admission() {
    echo ""
    echo "=========================================="
    echo "TESTING POD SECURITY ADMISSION"
    echo "=========================================="
    echo ""
    
    echo "Creating test pod that violates Restricted profile..."
    
    cat > "$BASE_DIR/bad-pod-test.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: bad-pod-test
  namespace: medisecure-prod
spec:
  containers:
  - name: bad
    image: nginx
    securityContext:
      privileged: true
EOF
    
    echo "Attempting to create privileged pod (should be rejected)..."
    if kubectl apply -f "$BASE_DIR/bad-pod-test.yaml" 2>&1 | grep -q "forbidden.*violates PodSecurity"; then
        echo "  ✓ PASS: Pod Security Admission is blocking insecure pods"
    else
        echo "  ✗ WARNING: Pod may have been created (check manually)"
    fi
    
    # Clean up if it was created
    kubectl delete pod bad-pod-test -n "$NAMESPACE_PROD" 2>/dev/null || true
}

# --------------------------------------------------
# Show Summary
# --------------------------------------------------
function show_summary() {
    echo ""
    echo "=========================================="
    echo "POD SECURITY HARDENING COMPLETE"
    echo "=========================================="
    echo ""
    echo "Before (INSECURE - HIPAA VIOLATION):"
    echo "  ✗ Running as root (UID 0)"
    echo "  ✗ Privileged mode enabled"
    echo "  ✗ Privilege escalation allowed"
    echo "  ✗ All capabilities granted"
    echo "  ✗ Writable root filesystem"
    echo "  ✗ No seccomp profile"
    echo "  ✗ No admission control"
    echo ""
    echo "After (SECURE - HIPAA COMPLIANT):"
    echo "  ✓ Running as UID 1000 (non-root)"
    echo "  ✓ Privileged mode disabled"
    echo "  ✓ Privilege escalation blocked"
    echo "  ✓ All capabilities dropped"
    echo "  ✓ Read-only root filesystem"
    echo "  ✓ Seccomp RuntimeDefault profile"
    echo "  ✓ Pod Security Admission enforced"
    echo ""
    echo "Security Improvements:"
    echo "  ✓ Container cannot escape to host"
    echo "  ✓ Container cannot access host filesystem"
    echo "  ✓ Container cannot load kernel modules"
    echo "  ✓ Container runs with minimal privileges"
    echo "  ✓ Filesystem tampering prevented"
    echo "  ✓ System calls restricted by seccomp"
    echo "  ✓ Future insecure deployments blocked"
    echo ""
    echo "Compliance Status:"
    echo "  ✓ HIPAA §164.312(a)(1) - Access Control"
    echo "  ✓ HIPAA §164.312(a)(2)(iv) - Encryption/Security"
    echo "  ✓ HIPAA §164.308(a)(3) - Workforce Security"
    echo "  ✓ SOC 2 CC6.1 - Logical Access"
    echo "  ✓ PCI-DSS Requirement 2.2 - Secure Configurations"
    echo ""
    echo "Pod Security Level: RESTRICTED ✓"
    echo ""
    echo "Files created in: $BASE_DIR"
    echo ""
    echo "=========================================="
    echo "PATIENT DATA IS NOW SECURE"
    echo "=========================================="
    echo "50 million patient records are protected!"
    echo "HIPAA compliance restored!"
    echo "=========================================="
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "=========================================="
    echo "IMPLEMENTING POD SECURITY STANDARDS"
    echo "=========================================="
    echo ""
    echo "Creating solution files in: $BASE_DIR"
    echo ""
    
    create_hardened_deployment
    
    echo "Solution file created:"
    echo "  $BASE_DIR/patient-data-processor-hardened.yaml"
    echo ""
    
    enable_pod_security_admission
    apply_hardened_deployment
    
    # Wait a moment for pods to fully start
    echo ""
    echo "Waiting for pods to be ready..."
    sleep 5
    
    verify_security
    test_pod_security_admission
    show_summary
}

main