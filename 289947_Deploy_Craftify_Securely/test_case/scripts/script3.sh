#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

export AWS_PAGER=""

mkdir -p /root/.aws
cp /home/user/.aws/credentials /root/.aws/credentials 2>/dev/null || true
cp /home/user/.aws/config /root/.aws/config 2>/dev/null || true
mkdir -p /root/.kube
cp /home/user/.kube/config /root/.kube/config 2>/dev/null || true

function load_config() {
    local config="/home/user/craftify-eks-lab/lab-config.txt"
    if [ ! -f "$config" ]; then
        print_status "failed" "Lab Failed: Lab config not found. Run setup.sh first."
        exit 1
    fi
    source "$config"
}

function test_node_group_exists() {
    load_config

    local ng_status
    ng_status=$(aws eks describe-nodegroup \
        --cluster-name "$CLUSTER_NAME" \
        --nodegroup-name "craftify-node-group" \
        --region "$REGION" \
        --query "nodegroup.status" \
        --output text 2>/dev/null || echo "")

    if [ -z "$ng_status" ] || [ "$ng_status" == "None" ]; then
        print_status "failed" "Lab Failed: Node group 'craftify-node-group' not found in cluster '$CLUSTER_NAME'. Create it with the craftify-eks-node-role."
        exit 1
    fi

    if [ "$ng_status" != "ACTIVE" ]; then
        print_status "failed" "Lab Failed: Node group status is '$ng_status'. Wait for it to become ACTIVE before deploying."
        exit 1
    fi
    print_status "success" "Lab Passed: Node group 'craftify-node-group' is ACTIVE."
}

function test_pod_is_running() {
    load_config

    local pod_status
    pod_status=$(kubectl get pods \
        --selector=app=craftify \
        --output jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")

    if [ -z "$pod_status" ]; then
        print_status "failed" "Lab Failed: No pod found with label 'app=craftify'. Apply the deployment.yaml file."
        exit 1
    fi

    if [ "$pod_status" != "Running" ]; then
        print_status "failed" "Lab Failed: Pod status is '$pod_status'. Wait for it to reach Running state. Check logs with: kubectl describe pod <POD-NAME>"
        exit 1
    fi
    print_status "success" "Lab Passed: Craftify pod is Running."
}

function test_pod_uses_ecr_image() {
    load_config

    local image
    image=$(kubectl get pods \
        --selector=app=craftify \
        --output jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || echo "")

    if ! echo "$image" | grep -q "$ECR_REPO_NAME"; then
        print_status "failed" "Lab Failed: Pod is not using the ECR image. Got: '$image'. Update deployment.yaml to use the ECR URI."
        exit 1
    fi

    if ! echo "$image" | grep -q "hardened"; then
        print_status "failed" "Lab Failed: Pod image tag is not 'hardened'. Got: '$image'. Push the hardened image and update the deployment."
        exit 1
    fi
    print_status "success" "Lab Passed: Pod is using the correct hardened ECR image."
}

test_node_group_exists
test_pod_is_running
test_pod_uses_ecr_image

print_status "success" "Lab Passed: Node group is active, pod is running, and the hardened ECR image is deployed."
exit 0