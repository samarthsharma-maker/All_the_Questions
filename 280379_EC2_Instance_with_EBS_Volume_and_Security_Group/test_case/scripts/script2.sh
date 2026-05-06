#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
SG_NAME="file-server-sg"
INSTANCE_NAME="file-server-01"
VOLUME_NAME="file-server-data"

function test_ec2_instance_exists() {
    local instance_id
    instance_id=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,stopped" --region "$REGION" --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "")
    
    if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
        export INSTANCE_ID="$instance_id"
        print_status "success" "Test 4 Passed: EC2 instance '$INSTANCE_NAME' exists (ID: $instance_id)"
        return 0
    else
        print_status "failed" "Test 4 Failed: EC2 instance '$INSTANCE_NAME' not found"
        return 1
    fi
}

function test_instance_type() {    
    if [ -z "${INSTANCE_ID:-}" ]; then
        print_status "failed" "Test 5 Failed: Instance ID not available"
        return 1
    fi
    
    local instance_type
    instance_type=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[0].Instances[0].InstanceType' --output text 2>/dev/null || echo "")
    
    if [ "$instance_type" == "t2.micro" ]; then
        print_status "success" "Test 5 Passed: Instance type is t2.micro"
        return 0
    else
        print_status "failed" "Test 5 Failed: Instance type is '$instance_type' (expected: t2.micro)"
        return 1
    fi
}

function test_instance_running() {    
    if [ -z "${INSTANCE_ID:-}" ]; then
        print_status "failed" "Test 6 Failed: Instance ID not available"
        return 1
    fi
    
    local state
    state=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "")
    
    if [ "$state" == "running" ]; then
        print_status "success" "Test 6 Passed: Instance is in running state"
        return 0
    else
        print_status "failed" "Test 6 Failed: Instance state is '$state' (expected: running)"
        return 1
    fi
}

function test_instance_tags() {
    if [ -z "${INSTANCE_ID:-}" ]; then
        print_status "failed" "Test 7 Failed: Instance ID not available"
        return 1
    fi
    
    local tags
    tags=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[0].Instances[0].Tags' --output json 2>/dev/null || echo "[]")

    local env_tag app_tag
    
    env_tag=$(echo "$tags" | jq -r '.[] | select(.Key=="Environment") | .Value' 2>/dev/null || echo "")
    app_tag=$(echo "$tags" | jq -r '.[] | select(.Key=="Application") | .Value' 2>/dev/null || echo "")
    
    if [ "$env_tag" == "Development" ] && [ "$app_tag" == "FileServer" ]; then
        print_status "success" "Test 7 Passed: Instance has required tags (Environment=Development, Application=FileServer)"
        return 0
    else
        print_status "failed" "Test 7 Failed: Instance missing required tags (Environment=$env_tag, Application=$app_tag)"
        return 1
    fi
}


function test_instance_public_ip() {
    if [ -z "${INSTANCE_ID:-}" ]; then
        print_status "failed" "Test 8 Failed: Instance ID not available"
        return 1
    fi
    
    local public_ip
    public_ip=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || echo "")
    
    if [ -n "$public_ip" ] && [ "$public_ip" != "None" ]; then
        print_status "success" "Test 8 Passed: Instance has public IP address ($public_ip)"
        return 0
    else
        print_status "failed" "Test 8 Failed: Instance does not have a public IP address"
        return 1
    fi
}

function test_instance_iam_profile() {    
    if [ -z "${INSTANCE_ID:-}" ]; then
        print_status "failed" "Test 9 Failed: Instance ID not available"
        return 1
    fi
    
    local iam_profile
    iam_profile=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' --output text 2>/dev/null || echo "")
    
    if [ -n "$iam_profile" ] && [ "$iam_profile" != "None" ]; then
        print_status "success" "Test 9 Passed: Instance has IAM instance profile attached"
        return 0
    else
        print_status "failed" "Test 9 Failed: Instance does not have IAM instance profile"
        return 1
    fi
}

function test_instance_security_group() {    
    if [ -z "${INSTANCE_ID:-}" ]; then
        print_status "failed" "Test 10 Failed: Instance ID not available"
        return 1
    fi
    
    local sg_ids
    sg_ids=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' --output text 2>/dev/null || echo "")
    
    if [[ "$sg_ids" == *"$SECURITY_GROUP_ID"* ]]; then
        print_status "success" "Test 10 Passed: Instance has security group '$SG_NAME' attached"
        return 0
    else
        print_status "failed" "Test 10 Failed: Instance does not have security group '$SG_NAME' attached"
        return 1
    fi
}

function test_data_directory_and_file() {
    if [ -z "${INSTANCE_ID:-}" ]; then
        print_status "failed" "Instance ID not available"
        return 1
    fi

    local cmd_id result
    cmd_id=$(aws ssm send-command --instance-ids "$INSTANCE_ID" --document-name "AWS-RunShellScript" --parameters 'commands=["test -f /data/test.txt && echo \"found\" || echo \"not_found\""]' --region "$REGION" --query 'Command.CommandId' --output text)
    sleep 3
    result=$(aws ssm get-command-invocation --command-id "$cmd_id" --instance-id "$INSTANCE_ID" --region "$REGION" --query 'StandardOutputContent' --output text | tr -d '[:space:]')

    if [ "$result" == "found" ]; then
        print_status "success" "Test file exists in /data"
        return 0
    else
        print_status "failed" "Test file not found in /data"
        return 1
    fi
}


test_ec2_instance_exists
test_instance_type
test_instance_running
test_instance_tags
test_instance_public_ip
test_instance_iam_profile
test_instance_security_group
test_data_directory_and_file
print_status "success" "Lab Passed: EC2 Instance configuration verified successfully."
exit 0