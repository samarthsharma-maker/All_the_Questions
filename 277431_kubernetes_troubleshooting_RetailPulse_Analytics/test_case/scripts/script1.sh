#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

# ==========================================
# Variables
# ==========================================
NAMESPACE="techflow-prod"
DEPLOYMENT="payment-gateway"
CONFIGMAP="gateway-config"
INIT_CONTAINER="config-guardian"
MAIN_CONTAINER="gateway"
LABEL_SELECTOR="app=payment-gateway"
REQUIRED_REPLICAS=3

# ConfigMap required keys
REQUIRED_CONFIG_KEYS="SERVICE_NAME SERVICE_VERSION DATABASE_URL REDIS_URL MAX_CONNECTIONS TIMEOUT_SECONDS"

# ==========================================
# Test 1: Namespace Existence
# ==========================================
function test_namespace_exists() {
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: Namespace '$NAMESPACE' does not exist."
        exit 1
    fi
    print_status "success" "Lab Passed: Namespace '$NAMESPACE' exists."
}

# ==========================================
# Test 2: ConfigMap Existence
# ==========================================
function test_configmap_exists() {
    if ! kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: ConfigMap '$CONFIGMAP' does not exist in namespace '$NAMESPACE'."
        exit 1
    fi
    print_status "success" "Lab Passed: ConfigMap '$CONFIGMAP' exists."
}

# ==========================================
# Test 3: ConfigMap Contains All Required Keys
# ==========================================
function test_configmap_content() {
    local config_data
    config_data=$(kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.gateway\.conf}' 2>/dev/null)
    
    if [ -z "$config_data" ]; then
        print_status "failed" "Lab Failed: ConfigMap '$CONFIGMAP' does not contain 'gateway.conf' key."
        exit 1
    fi
    
    for key in $REQUIRED_CONFIG_KEYS; do
        if ! echo "$config_data" | grep -q "^${key}="; then
            print_status "failed" "Lab Failed: ConfigMap is missing required key: $key"
            exit 1
        fi
    done
    
    print_status "success" "Lab Passed: ConfigMap contains all required configuration keys."
}

# ==========================================
# Test 4: Deployment Existence
# ==========================================
function test_deployment_exists() {
    if ! kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" &>/dev/null; then
        print_status "failed" "Lab Failed: Deployment '$DEPLOYMENT' does not exist in namespace '$NAMESPACE'."
        exit 1
    fi
    print_status "success" "Lab Passed: Deployment '$DEPLOYMENT' exists."
}

# ==========================================
# Test 5: Replica Count
# ==========================================
function test_replica_count() {
    local replicas
    replicas=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
    
    if [ "$replicas" != "$REQUIRED_REPLICAS" ]; then
        print_status "failed" "Lab Failed: Deployment does not have $REQUIRED_REPLICAS replicas (found: $replicas)."
        exit 1
    fi
    print_status "success" "Lab Passed: Deployment has correct replica count ($REQUIRED_REPLICAS)."
}

# ==========================================
# Test 6: Init Container Exists
# ==========================================
function test_init_container_exists() {
    local init_name
    init_name=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="'"$INIT_CONTAINER"'")].name}')
    
    if [ "$init_name" != "$INIT_CONTAINER" ]; then
        print_status "failed" "Lab Failed: Init container '$INIT_CONTAINER' not found in deployment."
        exit 1
    fi
    print_status "success" "Lab Passed: Init container '$INIT_CONTAINER' exists."
}

# ==========================================
# Test 7: Init Container Volume Mount
# ==========================================
function test_init_container_volume_mount() {
    local mount_path
    mount_path=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="'"$INIT_CONTAINER"'")].volumeMounts[*].mountPath}')
    
    if ! echo "$mount_path" | grep -q "/config"; then
        print_status "failed" "Lab Failed: Init container does not mount volume at '/config'."
        exit 1
    fi
    print_status "success" "Lab Passed: Init container has correct volume mount."
}

# ==========================================
# Test 8: Main Container Exists
# ==========================================
function test_main_container_exists() {
    local container_name
    container_name=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER"'")].name}')
    
    if [ "$container_name" != "$MAIN_CONTAINER" ]; then
        print_status "failed" "Lab Failed: Main container '$MAIN_CONTAINER' not found in deployment."
        exit 1
    fi
    print_status "success" "Lab Passed: Main container '$MAIN_CONTAINER' exists."
}

# ==========================================
# Test 9: Main Container Volume Mount
# ==========================================
function test_main_container_volume_mount() {
    local mount_path
    mount_path=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER"'")].volumeMounts[*].mountPath}')
    
    if ! echo "$mount_path" | grep -q "/etc/techflow"; then
        print_status "failed" "Lab Failed: Main container does not mount volume at '/etc/techflow'."
        exit 1
    fi
    print_status "success" "Lab Passed: Main container has correct volume mount."
}

# ==========================================
# Test 10: Init Container Resource Limits
# ==========================================
function test_init_container_resources() {
    local cpu_request cpu_limit mem_request mem_limit
    
    cpu_request=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="'"$INIT_CONTAINER"'")].resources.requests.cpu}')
    cpu_limit=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="'"$INIT_CONTAINER"'")].resources.limits.cpu}')
    mem_request=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="'"$INIT_CONTAINER"'")].resources.requests.memory}')
    mem_limit=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="'"$INIT_CONTAINER"'")].resources.limits.memory}')
    
    if [ "$cpu_request" != "50m" ] || [ "$cpu_limit" != "50m" ]; then
        print_status "failed" "Lab Failed: Init container CPU resources incorrect (expected: 50m/50m, found: $cpu_request/$cpu_limit)."
        exit 1
    fi
    
    if [ "$mem_request" != "64Mi" ] || [ "$mem_limit" != "64Mi" ]; then
        print_status "failed" "Lab Failed: Init container memory resources incorrect (expected: 64Mi/64Mi, found: $mem_request/$mem_limit)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Init container has correct resource limits."
}

# ==========================================
# Test 11: Main Container Resource Limits
# ==========================================
function test_main_container_resources() {
    local cpu_request cpu_limit mem_request mem_limit
    
    cpu_request=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER"'")].resources.requests.cpu}')
    cpu_limit=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER"'")].resources.limits.cpu}')
    mem_request=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER"'")].resources.requests.memory}')
    mem_limit=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER"'")].resources.limits.memory}')
    
    if [ "$cpu_request" != "200m" ] || [ "$cpu_limit" != "500m" ]; then
        print_status "failed" "Lab Failed: Main container CPU resources incorrect (expected: 200m/500m, found: $cpu_request/$cpu_limit)."
        exit 1
    fi
    
    if [ "$mem_request" != "256Mi" ] || [ "$mem_limit" != "512Mi" ]; then
        print_status "failed" "Lab Failed: Main container memory resources incorrect (expected: 256Mi/512Mi, found: $mem_request/$mem_limit)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Main container has correct resource limits."
}

# ==========================================
# Test 12: No Invalid NodeSelector
# ==========================================
function test_no_invalid_nodeselector() {
    local node_selector
    node_selector=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.nodeSelector}' 2>/dev/null)
    
    # If nodeSelector exists and contains 'workload: payments', fail
    if echo "$node_selector" | grep -q "payments"; then
        # Check if any nodes have this label
        local nodes_with_label
        nodes_with_label=$(kubectl get nodes -l workload=payments --no-headers 2>/dev/null | wc -l)
        
        if [ "$nodes_with_label" -eq 0 ]; then
            print_status "failed" "Lab Failed: NodeSelector 'workload: payments' matches no nodes."
            exit 1
        fi
    fi
    
    print_status "success" "Lab Passed: No invalid nodeSelector configured."
}

# ==========================================
# Test 13: Correct Image Name
# ==========================================
function test_correct_image() {
    local image
    image=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER"'")].image}')
    
    # Check for common typos
    if echo "$image" | grep -q "alpinee"; then
        print_status "failed" "Lab Failed: Image name contains typo 'alpinee' - should be 'alpine'."
        exit 1
    fi
    
    # Should be nginx:alpine or similar valid image
    if ! echo "$image" | grep -q "nginx:alpine"; then
        print_status "failed" "Lab Failed: Expected image 'nginx:alpine', found: $image"
        exit 1
    fi
    
    print_status "success" "Lab Passed: Correct image name configured."
}

# ==========================================
# Test 14: All Pods Running
# ==========================================
function test_all_pods_running() {
    local running_count
    
    # Wait up to 120 seconds for pods to be ready
    for i in {1..120}; do
        running_count=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" \
            --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
        
        if [ "$running_count" -eq "$REQUIRED_REPLICAS" ]; then
            break
        fi
        sleep 1
    done
    
    if [ "$running_count" -ne "$REQUIRED_REPLICAS" ]; then
        print_status "failed" "Lab Failed: Not all pods are running (expected: $REQUIRED_REPLICAS, found: $running_count)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: All $REQUIRED_REPLICAS pods are running."
}

# ==========================================
# Test 15: No Pods in Error State
# ==========================================
function test_no_error_pods() {
    local error_count
    error_count=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" --no-headers 2>/dev/null | \
        grep -E "ImagePullBackOff|CrashLoopBackOff|Error|ErrImagePull" | wc -l)
    
    if [ "$error_count" -gt 0 ]; then
        print_status "failed" "Lab Failed: Some pods are in error states (ImagePullBackOff, CrashLoopBackOff, etc.)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: No pods in error states."
}

# ==========================================
# Test 16: Init Container Validation Success
# ==========================================
function test_init_validation_success() {
    local pod_name init_logs
    
    # Get first running pod
    pod_name=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" \
        --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        print_status "failed" "Lab Failed: No running pods found to check init container logs."
        exit 1
    fi
    
    # Get init container logs
    init_logs=$(kubectl logs "$pod_name" -n "$NAMESPACE" -c "$INIT_CONTAINER" 2>/dev/null)
    
    # Check for validation success message
    if ! echo "$init_logs" | grep -q "All configuration parameters validated successfully"; then
        print_status "failed" "Lab Failed: Init container did not successfully validate configuration."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Init container successfully validated configuration."
}

# ==========================================
# Test 17: Deployment Available
# ==========================================
function test_deployment_available() {
    local available_replicas
    available_replicas=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.status.availableReplicas}')
    
    if [ "$available_replicas" != "$REQUIRED_REPLICAS" ]; then
        print_status "failed" "Lab Failed: Not all replicas are available (expected: $REQUIRED_REPLICAS, found: $available_replicas)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: All replicas are available."
}

# ==========================================
# Test 18: Config File Accessible in Main Container
# ==========================================
function test_config_file_accessible() {
    local pod_name
    
    pod_name=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" \
        --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        print_status "failed" "Lab Failed: No running pods found to check config file."
        exit 1
    fi
    
    # Check if config file exists in main container
    if ! kubectl exec "$pod_name" -n "$NAMESPACE" -c "$MAIN_CONTAINER" -- \
        test -f /etc/techflow/gateway.conf &>/dev/null; then
        print_status "failed" "Lab Failed: Configuration file not accessible at '/etc/techflow/gateway.conf'."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Configuration file is accessible in main container."
}

# ==========================================
# Test 19: Resource Requests Do Not Exceed Limits
# ==========================================
function test_resources_valid() {
    local cpu_request cpu_limit mem_request mem_limit
    
    cpu_request=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER"'")].resources.requests.cpu}')
    cpu_limit=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$MAIN_CONTAINER"'")].resources.limits.cpu}')
    
    # Convert to millicores for comparison
    cpu_req_milli=$(echo "$cpu_request" | sed 's/m//')
    cpu_lim_milli=$(echo "$cpu_limit" | sed 's/m//')
    
    if [ "$cpu_req_milli" -gt "$cpu_lim_milli" ]; then
        print_status "failed" "Lab Failed: CPU requests ($cpu_request) exceed limits ($cpu_limit)."
        exit 1
    fi
    
    print_status "success" "Lab Passed: Resource requests do not exceed limits."
}

# ==========================================
# Execute All Tests
# ==========================================
test_namespace_exists
test_configmap_exists
test_configmap_content
test_deployment_exists
test_replica_count
test_init_container_exists
test_init_container_volume_mount
test_main_container_exists
test_main_container_volume_mount
test_init_container_resources
test_main_container_resources
test_no_invalid_nodeselector
test_correct_image
test_all_pods_running
test_no_error_pods
test_init_validation_success
test_deployment_available
test_config_file_accessible
test_resources_valid

print_status "success" "Lab Passed: All tests completed successfully."

exit 0