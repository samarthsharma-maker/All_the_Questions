#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

PIPELINE="/home/user/deploy_report.py"
REPORT="/home/user/deployreports/summary.txt"

Test5() {
    if [[ ! -f "$PIPELINE" ]]; then
        print_status "failed" "Pipeline script not found at $PIPELINE."
        exit 1
    fi

    TMP_DIR=$(mktemp -d)
    TMP_CSV="${TMP_DIR}/deployments.csv"
    TMP_REPORT="${TMP_DIR}/summary.txt"

    # Synthetic data -- deliberately different counts and durations
    # alpha: 2 success, 2 failed -- durations 60, 120, 90, 30 -- avg=75
    # beta:  3 success, 0 failed -- durations 200, 100, 150    -- avg=150
    # gamma: 1 success, 1 failed -- durations 300, 600         -- avg=450
    # total_deployments=8, total_failed=3
    cat > "$TMP_CSV" << 'CSVEOF'
env,status,start_time,end_time
alpha,success,06:00:00,06:01:00
alpha,success,07:00:00,07:02:00
alpha,failed,08:00:00,08:01:30
alpha,failed,09:00:00,09:00:30
beta,success,06:00:00,06:03:20
beta,success,07:00:00,07:01:40
beta,success,08:00:00,08:02:30
gamma,success,06:00:00,06:05:00
gamma,failed,07:00:00,07:10:00
CSVEOF

    # Expected values:
    # alpha: total=4 success=2 failed=2 avg=75
    # beta:  total=3 success=3 failed=0 avg=150
    # gamma: total=2 success=1 failed=1 avg=450
    # total_deployments=9 total_failed=3

    run_output=$(python3 - << PYEOF 2>&1
import sys
sys.path.insert(0, "/home/user")
import deploy_report as dr

dr.CSV_FILE    = "${TMP_CSV}"
dr.REPORT_FILE = "${TMP_REPORT}"

try:
    dr.run_pipeline()
    print("EXIT_OK")
except Exception as e:
    print("EXIT_ERR:" + str(e))
PYEOF
)
    run_exit=$?

    if echo "$run_output" | grep -q "^EXIT_ERR:"; then
        err_msg=$(echo "$run_output" | grep "^EXIT_ERR:" | head -1 | sed 's/^EXIT_ERR://')
        print_status "failed" "Pipeline raised an exception on synthetic data: ${err_msg}. Make sure both functions work for any valid input."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    if [[ $run_exit -ne 0 ]] || ! echo "$run_output" | grep -q "EXIT_OK"; then
        print_status "failed" "Pipeline did not complete on synthetic data. Output: $(echo "$run_output" | tail -3 | tr '\n' ' ')"
        rm -rf "$TMP_DIR"
        exit 1
    fi

    if [[ ! -f "$TMP_REPORT" ]]; then
        print_status "failed" "Pipeline exited cleanly on synthetic data but no report file was created."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    if ! grep -qP 'total_deployments=9' "$TMP_REPORT"; then
        found=$(grep -oP 'total_deployments=\K[0-9]+' "$TMP_REPORT" || echo "0")
        print_status "failed" "Synthetic run: report shows total_deployments=${found} but expected 9. Your implementation may be hardcoding row counts instead of computing them."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    if ! grep -qP 'total_failed=3' "$TMP_REPORT"; then
        found=$(grep -oP 'total_failed=\K[0-9]+' "$TMP_REPORT" || echo "0")
        print_status "failed" "Synthetic run: report shows total_failed=${found} but expected 3. Check that group_by_env counts failed status dynamically."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    for check in "avg_duration_seconds=75" "avg_duration_seconds=150" "avg_duration_seconds=450"; do
        if ! grep -q "$check" "$TMP_REPORT"; then
            print_status "failed" "Synthetic run: report is missing '${check}'. Your average duration calculation may be hardcoded or rounding incorrectly."
            rm -rf "$TMP_DIR"
            exit 1
        fi
    done

    for env in alpha beta gamma; do
        if ! grep -q "$env" "$TMP_REPORT"; then
            print_status "failed" "Synthetic run: report is missing the '${env}' environment. The pipeline may be filtering to hardcoded environment names."
            rm -rf "$TMP_DIR"
            exit 1
        fi
    done

    rm -rf "$TMP_DIR"
    print_status "success" "Pipeline produced correct results on fresh synthetic data: 9 deployments, 3 failed, correct averages for alpha, beta, and gamma. No hardcoding detected."
}

Test5
