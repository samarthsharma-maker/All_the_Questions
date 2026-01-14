# ==========================================
# VALIDATION TEST: GLUE CRAWLER CLASSIFIER
# ==========================================

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

function test_glue_classifier_attachment() {
    local CRAWLER_NAME="raw-clickstream-crawler"
    local EXPECTED_CLASSIFIER="clickstream-csv-classifier"
    local REGION="us-west-2"

    # Get classifiers attached to crawler
    CLASSIFIERS=$(aws glue get-crawler --name "$CRAWLER_NAME" --region "$REGION" --query "Crawler.Classifiers[]" --output text)

    # Pass if the expected classifier exists in the crawler
    if [[ "$CLASSIFIERS" == *"$EXPECTED_CLASSIFIER"* ]]; then
        print_status "success" "Lab Passed: Crawler '$CRAWLER_NAME' has classifier '$EXPECTED_CLASSIFIER' attached."
    else
        print_status "failed" "Lab Failed: Crawler '$CRAWLER_NAME' does NOT have classifier '$EXPECTED_CLASSIFIER' attached."
        exit 1
    fi
}

test_glue_classifier_attachment

exit 0
