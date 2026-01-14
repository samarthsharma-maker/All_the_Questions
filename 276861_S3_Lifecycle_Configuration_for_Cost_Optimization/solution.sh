export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export bucket_name="mgt-lifecycle-lab-${ACCOUNT_ID}"
cat <<EOT > lifecycle.json
{
    "Rules": [
        {
            "ID": "MoveLogsToIA",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "logs/"
            },
            "Transitions": [
                {
                    "Days": 30,
                    "StorageClass": "STANDARD_IA"
                }
            ]
        },
        {
            "ID": "ArchiveOldRecords",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "archives/"
            },
            "Transitions": [
                {
                    "Days": 90,
                    "StorageClass": "GLACIER"
                }
            ],
            "Expiration": {
                "Days": 365
            }
        },
        {
            "ID": "CleanupTempProject",
            "Status": "Enabled",
            "Filter": {
                "Tag": {
                    "Key": "Project",
                    "Value": "Temp"
                }
            },
            "Expiration": {
                "Days": 7
            }
        }
    ]
}
EOT

aws s3api put-bucket-lifecycle-configuration --bucket "${bucket_name}" --lifecycle-configuration file://lifecycle.json --no-cli-pager

mkdir -p ./s3_lifecycle_data
echo "active log data" > ./s3_lifecycle_data/log_active.txt
echo "old archive data" > ./s3_lifecycle_data/archive_old.txt
echo "temporary project data" > ./s3_lifecycle_data/temp_project.txt

aws s3 cp ./s3_lifecycle_data/log_active.txt s3://mgt-lifecycle-lab-${ACCOUNT_ID}/logs/active.txt

aws s3 cp ./s3_lifecycle_data/archive_old.txt s3://mgt-lifecycle-lab-${ACCOUNT_ID}/archives/old.txt

aws s3api put-object --bucket mgt-lifecycle-lab-${ACCOUNT_ID} --key temp_project.txt --body ./s3_lifecycle_data/temp_project.txt --tagging "Project=Temp" --no-cli-pager