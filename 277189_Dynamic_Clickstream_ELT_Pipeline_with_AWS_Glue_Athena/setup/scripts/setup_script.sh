#!/bin/bash

set -euo pipefail


create_s3_bucket() {
    local region="${AWS_REGION:-us-west-2}"
    local bucket_prefix="clickstream-schema-evolution-bucket"
    local account_id=$(aws sts get-caller-identity --query Account --output text)

    if [ -z "$account_id" ]; then
        echo "Failed to retrieve AWS Account ID" >&2
        return 1
    fi

    local bucket_name="${bucket_prefix}-${account_id}"
    echo "Creating S3 bucket: s3://${bucket_name} in region ${region}" >&2

    if aws s3 mb "s3://${bucket_name}" --region "$region"; then
        echo "$bucket_name"
    else
        echo "Failed to create bucket ${bucket_name}" >&2
        return 1
    fi
}

create_sqs_queue() {
    local queue_prefix="ClickstreamSchemaEvolutionQueue"
    local region="${AWS_REGION:-us-west-2}"
    local account_id=$(aws sts get-caller-identity --query Account --output text)

    local queue_name="${queue_prefix}-${account_id}"

    echo "Creating SQS queue: ${queue_name}" >&2

    local queue_url
    queue_url=$(aws sqs create-queue --queue-name "$queue_name" --output text --query 'QueueUrl') || {
        echo "Failed to create SQS queue ${queue_name}" >&2
        return 1
    }
    echo "$queue_url"
}   

attach_sqs_policy() {
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local bucket_prefix="clickstream-schema-evolution-bucket"
    local bucket_name="${bucket_prefix}-${account_id}"
    local region="${AWS_REGION:-us-west-2}"
    local queue_prefix="ClickstreamSchemaEvolutionQueue"
    local queue_name="${queue_prefix}-${account_id}"

    local queue_url=$(aws sqs get-queue-url --queue-name "$queue_name" --region "$region" --output text --query 'QueueUrl') || {
        echo "Failed to get queue URL for ${queue_name}" >&2
        return 1
    }
    
    local queue_arn=$(aws sqs get-queue-attributes \
        --queue-url "$queue_url" \
        --attribute-names QueueArn \
        --output text \
        --query 'Attributes.QueueArn') || {
        echo "Failed to get queue ARN" >&2
        return 1
    }
    
    echo "Attaching policy to SQS queue to allow S3 notifications" >&2
    
    # Create a local temporary file for the policy
    local policy_file="./sqs_policy_temp.json"
    
    cat > "$policy_file" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Action": "SQS:SendMessage",
      "Resource": "${queue_arn}",
      "Condition": {
        "ArnLike": {
          "aws:SourceArn": "arn:aws:s3:::${bucket_name}"
        }
      }
    }
  ]
}
EOF
    
    # Create attributes file with proper JSON structure
    local attributes_file="./sqs_attributes_temp.json"
    
    cat > "$attributes_file" <<EOF
{
  "Policy": "$(cat "$policy_file" | sed 's/"/\\"/g' | tr -d '\n' | tr -s ' ')"
}
EOF
    
    # Set queue attributes using the attributes file
    if aws sqs set-queue-attributes \
        --queue-url "$queue_url" \
        --attributes "file://$attributes_file"; then
        echo "Queue policy attached successfully" >&2
    else
        echo "Failed to set queue policy" >&2
        rm -f "$policy_file" "$attributes_file"
        return 1
    fi
    
    # Clean up temporary files
    rm -f "$policy_file" "$attributes_file"
    
    echo "$queue_arn"
}

configure_s3_notification() {
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local bucket_prefix="clickstream-schema-evolution-bucket"
    local bucket_name="${bucket_prefix}-${account_id}"
    local region="${AWS_REGION:-us-west-2}"
    local queue_prefix="ClickstreamSchemaEvolutionQueue"
    local queue_name="${queue_prefix}-${account_id}"

    local queue_url=$(aws sqs get-queue-url --queue-name "$queue_name" --region "$region" --output text --query 'QueueUrl') || {
        echo "Failed to get queue URL for ${queue_name}" >&2
        return 1
    }
    
    local queue_arn=$(aws sqs get-queue-attributes \
        --queue-url "$queue_url" \
        --attribute-names QueueArn \
        --output text \
        --query 'Attributes.QueueArn') || {
        echo "Failed to get queue ARN" >&2
        return 1
    }
    
    echo "Configuring S3 bucket notification to SQS" >&2
    
    # Create a local temporary file for the notification configuration
    local notification_file="./s3_notification_temp.json"
    
    cat > "$notification_file" <<EOF
{
  "QueueConfigurations": [
    {
      "QueueArn": "${queue_arn}",
      "Events": ["s3:ObjectCreated:*"]
    }
  ]
}
EOF
    
    # Configure S3 notification using the file
    if aws s3api put-bucket-notification-configuration \
        --bucket "$bucket_name" \
        --notification-configuration "file://$notification_file"; then
        echo "S3 notification configured successfully" >&2
    else
        echo "Failed to configure S3 notification" >&2
        rm -f "$notification_file"
        return 1
    fi
    
    # Clean up temporary file
    rm -f "$notification_file"
}


create_s3_bucket
create_sqs_queue
attach_sqs_policy
configure_s3_notification
