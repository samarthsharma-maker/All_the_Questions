# ==========================================
# VALIDATION TEST: ATHENA PROCESSED TABLE
# ==========================================

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

function test_athena_processed_table() {
    local DB_NAME="clickstream_db"
    local TABLE_NAME="clickstream_processed"
    local REGION="us-west-2"

    TABLE_EXISTS=$(aws glue get-table \
        --database-name "$DB_NAME" \
        --name "$TABLE_NAME" \
        --region "$REGION" \
        --query "Table.Name" \
        --output text 2>/dev/null)

    if [[ "$TABLE_EXISTS" == "$TABLE_NAME" ]]; then
        print_status "success" "Lab Passed: Athena processed table '$TABLE_NAME' exists."
    else
        print_status "failed" "Lab Failed: Athena processed table '$TABLE_NAME' not found."
        exit 1
    fi
}

test_athena_processed_table
exit 0


DB_NAME="clickstream_db"
TABLE_NAME="clickstream_processed"
REGION="us-west-2"

TABLE_EXISTS=$(aws glue get-table \
    --database-name "$DB_NAME" \
    --name "$TABLE_NAME" \
    --region "$REGION" \
    --query "Table.Name" \
    --output text 2>/dev/null)

echo "Found table: $TABLE_EXISTS"

if [[ "$TABLE_EXISTS" == "$TABLE_NAME" ]]; then
    print_status "success" "Lab Passed: Athena processed table '$TABLE_NAME' exists."
else
    print_status "failed" "Lab Failed: Athena processed table '$TABLE_NAME' not found."
    exit 1
fi