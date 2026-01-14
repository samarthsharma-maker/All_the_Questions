#!/bin/bash
# Test: Verify no other fields except the compute block were changed

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/batch-engine.yaml"
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
  name: workload-engine
  namespace: production
  labels:
    app: workload-engine
    team: analytics
spec:
  replicas: 3
  selector:
    matchLabels:
      app: workload-engine
  template:
    metadata:
      labels:
        app: workload-engine
        environment: production
    spec:
      serviceAccountName: workload-engine-sa
      containers:
      - name: workload-engine
        image: cloudscale/workload-engine:v1.9.3
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: ENGINE_THREADS
          value: "6"
        - name: LOG_LEVEL
          value: "info"
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "400m"
            memory: "1Gi"
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 20
          periodSeconds: 10
EOF

# --- Strip ONLY the compute (resources) block ---
strip_compute() {
    awk '
        # Detect the indentation level of the resources: line
        /^([ ]*)resources:/ {
            indent = length(substr($0, 1, RLENGTH))
            skip = 1
            next
        }
        skip {
            cur = match($0, /[^ ]/) - 1
            if (cur <= indent) {
                skip = 0
            } else {
                next
            }
        }
        { print NR ":" $0 }
    ' "$1"
}


TMP_REF=$(mktemp)
TMP_STU=$(mktemp)

strip_compute "$REFERENCE" > "$TMP_REF"
strip_compute "$STUDENT"   > "$TMP_STU"

# --- Strict 1-to-1 comparison ---
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
