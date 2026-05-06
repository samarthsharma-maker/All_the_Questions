#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

HARVEST="/home/user/log-harvest"
REPORT="/home/user/log-report"
CSV="/home/user/logharvest/reports/daily.csv"

Test5() {
    if [[ ! -f "$HARVEST" ]]; then
        print_status "failed" "Script not found at /home/user/log-harvest."
        return
    fi

    # Run log-harvest and capture output
    harvest_output=$(bash "$HARVEST" 2>&1)
    harvest_exit=$?

    if [[ $harvest_exit -ne 0 ]]; then
        print_status "failed" "log-harvest exited with code $harvest_exit. Fix all bugs before running. Output: $(echo "$harvest_output" | tail -3 | tr '\n' ' ')"
        return
    fi

    # The sample logs contain: app=3, db=2, worker=2 = 7 total
    # Check the total errors line in output or written report
    DATE=$(date '+%Y-%m-%d')
    REPORT_FILE="/home/user/logharvest/reports/harvest_${DATE}.txt"

    total=0
    if [[ -f "$REPORT_FILE" ]]; then
        total=$(grep -oP 'Total Errors:\s*\K[0-9]+' "$REPORT_FILE" | head -1 || echo "0")
    else
        total=$(echo "$harvest_output" | grep -oP 'Total errors:\s*\K[0-9]+' | head -1 || echo "0")
    fi

    if [[ "$total" -eq 0 ]]; then
        print_status "failed" "log-harvest ran successfully but reported 0 total errors. The subshell scope bug is still present -- the error counter is being set inside a pipe subshell and is lost. Use process substitution: done < <(grep -rh 'ERROR' \"\$dir\")"
        return
    fi

    if [[ "$total" -ne 7 ]]; then
        print_status "failed" "log-harvest reported $total total errors but the expected count is 7 (app=3, db=2, worker=2). Check that all three log directories are scanned correctly."
        return
    fi

    print_status "success" "log-harvest correctly counted 7 total errors across all log directories."
}

Test6() {
    if [[ ! -f "$REPORT" ]]; then
        print_status "failed" "Script not found at /home/user/log-report."
        return
    fi

    if [[ ! -f "$CSV" ]]; then
        print_status "failed" "Sample CSV not found at $CSV. Ensure the setup script has been run."
        return
    fi

    report_output=$(bash "$REPORT" "$CSV" 2>&1)
    report_exit=$?

    if [[ $report_exit -ne 0 ]]; then
        print_status "failed" "log-report exited with code $report_exit. Output: $(echo "$report_output" | tail -3 | tr '\n' ' ')"
        return
    fi

    # Check all 3 services appear in output
    for svc in app db worker; do
        if ! echo "$report_output" | grep -q "$svc"; then
            print_status "failed" "log-report output is missing the '$svc' service line. The last-line bug may still be present -- the 'worker' row has no trailing newline and will be dropped if the read loop is not guarded with || [[ -n "${service:-}" ]]."
            return
        fi
    done

    # Check totals line shows services=3
    if ! echo "$report_output" | grep -qP 'services=3'; then
        services_found=$(echo "$report_output" | grep -oP 'services=\K[0-9]+' | head -1 || echo "0")
        print_status "failed" "log-report parsed $services_found service(s) but expected 3. The last line of the CSV has no trailing newline and is being silently dropped. Fix the read loop: while IFS=',' read -r service date errors warns || [[ -n "${service:-}" ]]; do"
        return
    fi

    # Check error total
    if ! echo "$report_output" | grep -qP 'errors=7'; then
        print_status "failed" "log-report totals do not show errors=7. Verify all three CSV rows are being parsed and summed correctly."
        return
    fi

    print_status "success" "log-report parsed all 3 service rows correctly and computed the right totals (errors=7, warns=2, services=3)."
}

Test5
Test6