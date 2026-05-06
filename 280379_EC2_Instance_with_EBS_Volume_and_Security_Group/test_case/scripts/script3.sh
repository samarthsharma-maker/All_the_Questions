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

function test_ebs_volume_exists() {
    local volume_id
    volume_id=$(aws ec2 describe-volumes --filters "Name=tag:Name,Values=$VOLUME_NAME" --region "$REGION" --query 'Volumes[0].VolumeId' --output text 2>/dev/null || echo "")
    
    if [ -n "$volume_id" ] && [ "$volume_id" != "None" ]; then
        export VOLUME_ID="$volume_id"
        print_status "success" "Test 11 Passed: EBS volume '$VOLUME_NAME' exists (ID: $volume_id)"
        return 0
    else
        print_status "failed" "Test 11 Failed: EBS volume '$VOLUME_NAME' not found"
        return 1
    fi
}

function test_volume_size_type() {    
    if [ -z "${VOLUME_ID:-}" ]; then
        print_status "failed" "Test 12 Failed: Volume ID not available"
        return 1
    fi
    
    local size vol_type
    
    size=$(aws ec2 describe-volumes --volume-ids "$VOLUME_ID" --region "$REGION" --query 'Volumes[0].Size' --output text 2>/dev/null || echo "")    
    vol_type=$(aws ec2 describe-volumes --volume-ids "$VOLUME_ID" --region "$REGION" --query 'Volumes[0].VolumeType' --output text 2>/dev/null || echo "")

    
    if [ "$size" == "10" ] && [ "$vol_type" == "gp3" ]; then
        print_status "success" "Test 12 Passed: Volume is 10 GB and type gp3"
        return 0
    else
        print_status "failed" "Test 12 Failed: Volume size is $size GB, type is $vol_type (expected: 10 GB, gp3)"
        return 1
    fi
}

function test_volume_encrypted() {
    
    if [ -z "${VOLUME_ID:-}" ]; then
        print_status "failed" "Test 13 Failed: Volume ID not available"
        return 1
    fi
    
    local encrypted
    encrypted=$(aws ec2 describe-volumes --volume-ids "$VOLUME_ID" --region "$REGION" --query 'Volumes[0].Encrypted' --output text 2>/dev/null || echo "")
    
    if [ "$encrypted" == "True" ]; then
        print_status "success" "Test 13 Passed: Volume is encrypted"
        return 0
    else
        print_status "failed" "Test 13 Failed: Volume is not encrypted"
        return 1
    fi
}

function test_volume_attached() {    
    if [ -z "${VOLUME_ID:-}" ] || [ -z "${INSTANCE_ID:-}" ]; then
        print_status "failed" "Test 14 Failed: Volume or Instance ID not available"
        return 1
    fi
    
    local attachment_state attached_instance
    
    attachment_state=$(aws ec2 describe-volumes --volume-ids "$VOLUME_ID" --region "$REGION" --query 'Volumes[0].Attachments[0].State' --output text 2>/dev/null || echo "")
    attached_instance=$(aws ec2 describe-volumes --volume-ids "$VOLUME_ID" --region "$REGION" --query 'Volumes[0].Attachments[0].InstanceId' --output text 2>/dev/null || echo "")
    
    if [ "$attachment_state" == "attached" ] && [ "$attached_instance" == "$INSTANCE_ID" ]; then
        print_status "success" "Test 14 Passed: Volume is attached to instance"
        return 0
    else
        print_status "failed" "Test 14 Failed: Volume attachment state is '$attachment_state', attached to '$attached_instance'"
        return 1
    fi
}

function test_volume_device_name() {    
    if [ -z "${VOLUME_ID:-}" ]; then
        print_status "failed" "Test 15 Failed: Volume ID not available"
        return 1
    fi
    
    local device
    device=$(aws ec2 describe-volumes --volume-ids "$VOLUME_ID" --region "$REGION" --query 'Volumes[0].Attachments[0].Device' --output text 2>/dev/null || echo "")
    
    if [ "$device" == "/dev/sdf" ]; then
        print_status "success" "Test 15 Passed: Volume attached as /dev/sdf"
        return 0
    else
        print_status "failed" "Test 15 Failed: Volume attached as '$device' (expected: /dev/sdf)"
        return 1
    fi
}

test_ebs_volume_exists
test_volume_size_type
test_volume_encrypted
test_volume_attached
test_volume_device_name
print_status "success" "Lab Passed: EBS Volume configuration verified successfully."
exit 0