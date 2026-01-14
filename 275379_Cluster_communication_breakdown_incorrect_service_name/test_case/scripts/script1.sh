#!/bin/bash
# Test: Ensure that ONLY the 'app:' label field has been modified
# Everything else MUST remain unchanged.

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"

FILES=(
  "component-pod.yaml"
  "component-service.yaml"
  "component-replicaset.yaml"
  "component-deployment.yaml"
)

###############################################
# Reference YAML generator
###############################################
make_reference() {
    local ref="$1"
    local tmp=$(mktemp)

    case "$ref" in

"component-pod.yaml")
cat << 'EOF' > "$tmp"
apiVersion: v1
kind: Pod
metadata:
  name: nova-app-pod
  labels:
    app: nova-app
spec:
  containers:
  - name: nova-app
    image: nginx:alpine
EOF
;;

"component-service.yaml")
cat << 'EOF' > "$tmp"
apiVersion: v1
kind: Service
metadata:
  name: nova-app-service
  labels:
    app: nova-app
spec:
  selector:
    app: nova-app
  ports:
  - port: 80
    targetPort: 80
EOF
;;

"component-replicaset.yaml")
cat << 'EOF' > "$tmp"
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nova-app-rs
  labels:
    app: nova-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nova-app
  template:
    metadata:
      labels:
        app: nova-app
    spec:
      containers:
      - name: nova-app
        image: nginx:alpine
EOF
;;

"component-deployment.yaml")
cat << 'EOF' > "$tmp"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nova-app-deploy
  labels:
    app: nova-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nova-app
  template:
    metadata:
      labels:
        app: nova-app
    spec:
      containers:
      - name: nova-app
        image: nginx:alpine
EOF
;;

    esac

    echo "$tmp"
}

###############################################
# Strip only allowed changes (app labels)
###############################################
strip_allowed() {
    # Remove ONLY the app: lines
    sed '/app:/d' "$1"
}

###############################################
# Main validation logic
###############################################
for F in "${FILES[@]}"; do
    STUDENT="$TARGET_DIR/$F"

    if [[ ! -f "$STUDENT" ]]; then
        print_status "failed" "File '$F' missing"
        exit 1
    fi

    REF=$(make_reference "$F")
    TMP_REF=$(mktemp)
    TMP_STU=$(mktemp)

    strip_allowed "$REF" > "$TMP_REF"
    strip_allowed "$STUDENT" > "$TMP_STU"

    # Compare line-by-line
    diff_output=$(diff -y --suppress-common-lines "$TMP_REF" "$TMP_STU")
    if [[ -n "$diff_output" ]]; then
        print_status "failed" "Unexpected modification detected in $F"
        exit 1
    fi
done

print_status "success" "All files validated — only 'app:' fields were modified."
exit 0