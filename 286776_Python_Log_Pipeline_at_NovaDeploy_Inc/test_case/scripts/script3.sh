#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

PIPELINE="/home/user/log_pipeline.py"
REPORT="/home/user/logreports/summary.txt"

Test5() {
    if [[ ! -f "$PIPELINE" ]]; then
        print_status "failed" "Pipeline script not found at $PIPELINE."
        exit 1
    fi
 
    # Create isolated temp directories so we never touch the lab files
    TMP_LOGS=$(mktemp -d)
    TMP_REPORT=$(mktemp -d)
    mkdir -p "${TMP_LOGS}/alpha" "${TMP_LOGS}/beta" "${TMP_LOGS}/gamma"
 
    # alpha: 1 ERROR, 2 WARN
    cat > "${TMP_LOGS}/alpha/alpha.log" << 'LOGEOF'
2024-06-10 07:00:01 INFO  Service alpha started
2024-06-10 07:15:00 ERROR Disk quota exceeded on /var/data
2024-06-10 08:00:00 WARN  CPU above 90% for 5 minutes
2024-06-10 09:00:00 WARN  Swap usage above threshold
2024-06-10 10:00:00 INFO  Cleanup job finished
LOGEOF
 
    # beta: 4 ERROR, 0 WARN
    cat > "${TMP_LOGS}/beta/beta.log" << 'LOGEOF'
2024-06-10 07:01:00 INFO  Beta service online
2024-06-10 07:30:00 ERROR Authentication token expired
2024-06-10 08:10:00 ERROR Rate limit breached on external API
2024-06-10 09:20:00 ERROR Cache invalidation failed for key user:99
2024-06-10 10:05:00 ERROR Upstream service returned 503
2024-06-10 11:00:00 INFO  Daily report generated
LOGEOF
 
    # gamma: 2 ERROR, 1 WARN
    cat > "${TMP_LOGS}/gamma/gamma.log" << 'LOGEOF'
2024-06-10 07:02:00 INFO  Gamma worker started
2024-06-10 08:00:00 WARN  Retry queue depth above 500
2024-06-10 09:00:00 ERROR Failed to write audit log: permission denied
2024-06-10 10:00:00 INFO  Heartbeat OK
2024-06-10 11:30:00 ERROR Schema migration timed out after 60s
LOGEOF
 
    # Expected: alpha errors=1 warns=2, beta errors=4 warns=0, gamma errors=2 warns=1
    # TOTAL:    errors=7  warns=3
    EXPECTED_ERRORS=7
    EXPECTED_WARNS=3
 
    # Run the pipeline against the synthetic dirs via a wrapper that
    # overrides SERVICES and REPORT_FILE before calling run_pipeline
    run_output=$(python3 - << PYEOF 2>&1
import sys
sys.path.insert(0, "/home/user")
import log_pipeline as lp
 
lp.SERVICES = {
    "alpha": "${TMP_LOGS}/alpha/alpha.log",
    "beta":  "${TMP_LOGS}/beta/beta.log",
    "gamma": "${TMP_LOGS}/gamma/gamma.log",
}
lp.REPORT_FILE = "${TMP_REPORT}/summary.txt"
 
try:
    lp.run_pipeline()
    print("EXIT_OK")
except Exception as e:
    print("EXIT_ERR:" + str(e))
PYEOF
)
    run_exit=$?
 
    if echo "$run_output" | grep -q "^EXIT_ERR:"; then
        err_msg=$(echo "$run_output" | grep "^EXIT_ERR:" | head -1 | sed 's/^EXIT_ERR://')
        print_status "failed" "Pipeline raised an exception on fresh log files: ${err_msg}. Make sure both functions work for any input, not just the lab files."
        rm -rf "$TMP_LOGS" "$TMP_REPORT"
        exit 1
    fi
 
    if [[ $run_exit -ne 0 ]] || ! echo "$run_output" | grep -q "EXIT_OK"; then
        print_status "failed" "Pipeline did not complete on the synthetic log files. Output: $(echo "$run_output" | tail -3 | tr '\n' ' ')"
        rm -rf "$TMP_LOGS" "$TMP_REPORT"
        exit 1
    fi
 
    SYNTH_REPORT="${TMP_REPORT}/summary.txt"
 
    if [[ ! -f "$SYNTH_REPORT" ]]; then
        print_status "failed" "Pipeline exited cleanly but did not write a report file. Ensure run_pipeline calls write_report with the summaries list."
        rm -rf "$TMP_LOGS" "$TMP_REPORT"
        exit 1
    fi
 
    total_errors=$(grep -oP 'errors=\K[0-9]+' "$SYNTH_REPORT" | tail -1 || echo "0")
    total_warns=$(grep -oP 'warnings=\K[0-9]+' "$SYNTH_REPORT" | tail -1 || echo "0")
 
    if [[ "$total_errors" != "$EXPECTED_ERRORS" ]]; then
        print_status "failed" "Synthetic run: report shows errors=${total_errors} but expected ${EXPECTED_ERRORS} (alpha=1, beta=4, gamma=2). Your implementation may be hardcoding counts instead of computing them from the parsed lines."
        rm -rf "$TMP_LOGS" "$TMP_REPORT"
        exit 1
    fi
 
    if [[ "$total_warns" != "$EXPECTED_WARNS" ]]; then
        print_status "failed" "Synthetic run: report shows warnings=${total_warns} but expected ${EXPECTED_WARNS} (alpha=2, beta=0, gamma=1). Check that summarize counts WARN entries dynamically."
        rm -rf "$TMP_LOGS" "$TMP_REPORT"
        exit 1
    fi
 
    for svc in alpha beta gamma; do
        if ! grep -q "$svc" "$SYNTH_REPORT"; then
            print_status "failed" "Synthetic report is missing the '${svc}' service line. The pipeline may be iterating over a hardcoded SERVICES dict instead of the one passed in."
            rm -rf "$TMP_LOGS" "$TMP_REPORT"
            exit 1
        fi
    done
 
    rm -rf "$TMP_LOGS" "$TMP_REPORT"
    print_status "success" "Pipeline produced correct counts on fresh synthetic logs: errors=${EXPECTED_ERRORS}, warnings=${EXPECTED_WARNS} across alpha, beta, and gamma. No hardcoding detected."
}
Test5
