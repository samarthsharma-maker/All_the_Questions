source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mgt-lifecycle-lab-${ACCOUNT_ID}"

LIFECYCLE=$(aws s3api get-bucket-lifecycle-configuration --bucket "${BUCKET_NAME}" 2>/dev/null)

if [[ -z "$LIFECYCLE" ]]; then
    print_status "failed" "No lifecycle configuration found for bucket '${BUCKET_NAME}'"
    exit 1
fi

# CHANGED: ArchiveOldLogs -> ArchiveOldRecords
ARCHIVE_RULE=$(echo "$LIFECYCLE" | jq -r '.Rules[] | select(.ID=="ArchiveOldRecords")')
if [[ -z "$ARCHIVE_RULE" ]]; then
    print_status "failed" "Lifecycle rule 'ArchiveOldRecords' not found in bucket '${BUCKET_NAME}'"
    exit 1
fi

ARCHIVE_DAYS=$(echo "$ARCHIVE_RULE" | jq -r '.Transitions[] | select(.StorageClass=="GLACIER") | .Days')
if [[ "$ARCHIVE_DAYS" -ne 90 ]]; then
    print_status "failed" "Lifecycle rule 'ArchiveOldRecords' should transition objects to GLACIER after 90 days, found ${ARCHIVE_DAYS} days"
    exit 1
fi

# CHANGED: DeleteTempFiles -> CleanupTempProject
TEMP_RULE=$(echo "$LIFECYCLE" | jq -r '.Rules[] | select(.ID=="CleanupTempProject")')
if [[ -z "$TEMP_RULE" ]]; then
    print_status "failed" "Lifecycle rule 'CleanupTempProject' not found in bucket '${BUCKET_NAME}'"
    exit 1
fi

TEMP_DAYS=$(echo "$TEMP_RULE" | jq -r '.Expiration.Days')
if [[ "$TEMP_DAYS" -ne 7 ]]; then
    print_status "failed" "Lifecycle rule 'CleanupTempProject' should expire objects after 7 days, found ${TEMP_DAYS} days"
    exit 1
fi

print_status "success" "S3 bucket lifecycle configuration verified."
exit 0