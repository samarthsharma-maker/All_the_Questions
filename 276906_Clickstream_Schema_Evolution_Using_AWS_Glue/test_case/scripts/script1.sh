# ==========================================
# SIMPLE VALIDATION TEST
# ==========================================

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

function test_glue_table_creation() {
    local DB_NAME="clickstream_db"
    local REGION="us-west-2"

    TABLE_NAME=$(aws glue get-tables --database-name "$DB_NAME" --region "$REGION" --query "TableList[0].Name" --output text)

    # Pass if a table name is returned (i.e., not "None" or empty)
    if [[ "$TABLE_NAME" != "None" && -n "$TABLE_NAME" ]]; then
        print_status "success" "Lab Passed: Glue Table '$TABLE_NAME' was created."
    else
        print_status "failed" "Lab Failed: No Glue Table found in database '$DB_NAME'."
        exit 1
    fi
}

test_glue_table_creation