#!/bin/bash
# Test: Ensure no fields except the container ports were modified

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"

FILES=(
  "service-a-deployment.yaml"
  "service-b-replicaset.yaml"
  "service-c-pod.yaml"
  "service-d-deployment.yaml"
)

###############################################
# Embedded reference YAMLs (port values wrong intentionally)
###############################################
make_reference() {
    local ref_file="$1"
    local tmp=$(mktemp)

    case "$ref_file" in
        "service-a-deployment.yaml")
cat << 'EOF' > "$tmp"
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
        ;;
        "service-b-replicaset.yaml")
cat << 'EOF' > "$tmp"
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
        ;;
        "service-c-pod.yaml")
cat << 'EOF' > "$tmp"
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
        ;;
        "service-d-deployment.yaml")
cat << 'EOF' > "$tmp"
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
        - containerPort: 3001
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
        ;;
    esac

    echo "$tmp"
}

###############################################
# Function: Remove ONLY port-related lines
###############################################
strip_ports() {
    awk '
        # Track probe context
        /readinessProbe:/ { in_probe=1 }
        /livenessProbe:/  { in_probe=1 }

        # Exit probe context when encountering a non-indented line
        in_probe && /^[^[:space:]]/ { in_probe=0 }

        # Remove containerPort lines always
        /containerPort:/ { next }

        # Remove port: ONLY when inside probe context
        in_probe && /port:/ { next }

        { print }
    ' "$1"
}


###############################################
# Main loop over all YAML files
###############################################
for FILE in "${FILES[@]}"; do
    STUDENT="${TARGET_DIR}/${FILE}"

    if [[ ! -f "$STUDENT" ]]; then
        print_status "failed" "File '$FILE' missing"
        exit 1
    fi

    REF=$(make_reference "$FILE")
    TMP_REF=$(mktemp)
    TMP_STU=$(mktemp)

    strip_ports "$REF"    > "$TMP_REF"
    strip_ports "$STUDENT" > "$TMP_STU"

    exec 3<"$TMP_REF"
    exec 4<"$TMP_STU"

    while true; do
        read -r ref_line <&3 || break
        read -r stu_line <&4 || break

        ref_val="${ref_line#*:}"
        stu_val="${stu_line#*:}"

        if [[ "$ref_val" != "$stu_val" ]]; then
            # Extract just the first token (field name)
            field=$(echo "$ref_val" | awk '{print $1}')
            print_status "failed" "Unexpected change detected in $FILE at field '$field'"
            exit 1
        fi
    done
done

print_status "success" "All files validated — no unintended changes found."
exit 0
