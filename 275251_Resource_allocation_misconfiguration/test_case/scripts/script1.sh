#!/bin/bash
# Test: Verify no other fields except resources were changed

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/data-processor-deployment.yaml"
STUDENT="$TARGET_FILE"

if [[ ! -f "$STUDENT" ]]; then
    print_status "failed" "Student file not found"
    exit 1
fi

# --- Embed reference YAML ---
REFERENCE=$(mktemp)
cat << 'EOF' > "$REFERENCE"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-processor
  namespace: production
  labels:
    app: data-processor
    environment: production
    team: analytics
spec:
  replicas: 3
  selector:
    matchLabels:
      app: data-processor
  template:
    metadata:
      labels:
        app: data-processor
        environment: production
    spec:
      containers:
      - name: data-processor
        image: cloudscale/data-processor:v2.4.1
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 9090
          name: metrics
          protocol: TCP
        env:
        - name: JAVA_OPTS
          value: "-Xmx3g -Xms512m"
        - name: PROCESSING_THREADS
          value: "4"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: url
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 20
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        volumeMounts:
        - name: config
          mountPath: /etc/config
        - name: cache
          mountPath: /var/cache/processor
      volumes:
      - name: config
        configMap:
          name: data-processor-config
      - name: cache
        emptyDir:
          sizeLimit: 10Gi
      serviceAccountName: data-processor-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
EOF

# --- Strip ONLY resources block ---
strip_resources() {
    awk '
        /^ *resources:/ { skip=1; next }
        skip && /^ *[^ ]/ { skip=0 }
        skip { next }
        { print NR ":" $0 }
    ' "$1"
}

TMP_REF=$(mktemp)
TMP_STU=$(mktemp)

strip_resources "$REFERENCE" > "$TMP_REF"
strip_resources "$STUDENT"   > "$TMP_STU"

# --- Strict comparison: NO pipeline (avoids subshell) ---
exec 3<"$TMP_REF"
exec 4<"$TMP_STU"

while true; do
    read -r ref_line <&3 || break
    read -r stu_line <&4 || break

    ref_num="${ref_line%%:*}"
    ref_val="${ref_line#*:}"
    stu_num="${stu_line%%:*}"
    stu_val="${stu_line#*:}"

    if [[ "$ref_val" != "$stu_val" ]]; then
        field=$(echo "$ref_val" | awk '{print $1}')
        print_status "failed" "line $stu_num field '$field' expected \"$ref_val\""
        exit 1
    fi
done

print_status "success" "no other fields changed"
exit 0
