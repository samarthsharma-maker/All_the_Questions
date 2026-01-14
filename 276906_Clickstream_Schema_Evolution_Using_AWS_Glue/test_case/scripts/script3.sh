# ==========================================
# VALIDATION TEST: GLUE TABLE COLUMN NAMES
# ==========================================

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

function test_glue_table_columns() {
    local DB_NAME="clickstream_db"
    local REGION="us-west-2"
    local EXPECTED_COLUMNS=("user_id" "event_time" "event_type" "page_url")

    # Get the first table in the database
    local TABLE_NAME
    TABLE_NAME=$(aws glue get-tables --database-name "$DB_NAME" --region "$REGION" --query "TableList[0].Name" --output text)

    if [[ -z "$TABLE_NAME" || "$TABLE_NAME" == "None" ]]; then
        print_status "failed" "No Glue table found in database '$DB_NAME'."
        exit 1
    fi

    local TABLE_COLUMNS
    TABLE_COLUMNS=$(aws glue get-table --database-name "$DB_NAME" --name "$TABLE_NAME" --region "$REGION" --query "Table.StorageDescriptor.Columns[].Name" --output text)

    # Check for missing columns
    local MISSING_COLUMNS=()
    for col in "${EXPECTED_COLUMNS[@]}"; do
        if ! echo "$TABLE_COLUMNS" | grep -qw "$col"; then
            MISSING_COLUMNS+=("$col")
        fi
    done

    if [[ ${#MISSING_COLUMNS[@]} -eq 0 ]]; then
        print_status "success" "Table '$TABLE_NAME' contains all expected columns: ${EXPECTED_COLUMNS[*]}"
    else
        print_status "failed" "Table '$TABLE_NAME' is missing columns: ${MISSING_COLUMNS[*]}"
        exit 1
    fi
}

test_glue_table_columns