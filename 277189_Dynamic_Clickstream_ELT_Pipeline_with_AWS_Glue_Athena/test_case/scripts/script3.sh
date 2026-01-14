# ==========================================
# VALIDATION TEST: TIMESTAMP TRANSFORMATION
# ==========================================

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

function test_timestamp_column_type() {
    local DB_NAME="clickstream_db"
    local TABLE_NAME="clickstream_processed"
    local REGION="us-west-2"

    COLUMN_TYPE=$(aws glue get-table \
        --database-name "$DB_NAME" \
        --name "$TABLE_NAME" \
        --region "$REGION" \
        --query "Table.StorageDescriptor.Columns[?Name=='event_timestamp'].Type | [0]" \
        --output text)

    if [[ "$COLUMN_TYPE" == "timestamp" ]]; then
        print_status "success" "Lab Passed: 'event_timestamp' column is of type TIMESTAMP."
    else
        print_status "failed" "Lab Failed: 'event_timestamp' is not TIMESTAMP (found: $COLUMN_TYPE)."
        exit 1
    fi
}

test_timestamp_column_type
exit 0
