# ==========================================
# VALIDATION TEST: SCHEMA EVOLUTION COLUMN
# ==========================================

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

function test_schema_evolution_column() {
    local DB_NAME="clickstream_db"
    local REGION="us-west-2"
    local EXPECTED_COLUMN="session_duration"

    TABLE_NAME=$(aws glue get-tables \
        --database-name "$DB_NAME" \
        --region "$REGION" \
        --query "TableList[0].Name" \
        --output text)

    if [[ -z "$TABLE_NAME" || "$TABLE_NAME" == "None" ]]; then
        print_status "failed" "No Glue table found in database '$DB_NAME'."
        exit 1
    fi

    TABLE_COLUMNS=$(aws glue get-table \
        --database-name "$DB_NAME" \
        --name "$TABLE_NAME" \
        --region "$REGION" \
        --query "Table.StorageDescriptor.Columns[].Name" \
        --output text)

    if echo "$TABLE_COLUMNS" | grep -qw "$EXPECTED_COLUMN"; then
        print_status "success" "Lab Passed: Schema evolution detected column '$EXPECTED_COLUMN'."
    else
        print_status "failed" "Lab Failed: Column '$EXPECTED_COLUMN' not found after schema evolution."
        exit 1
    fi
}

test_schema_evolution_column
exit 0
