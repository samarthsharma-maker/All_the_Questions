#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

PIPELINE="/home/user/log_pipeline.py"
REPORT="/home/user/logreports/summary.txt"

Test3() {
    result=$(python3 - << 'EOF'
import sys
sys.path.insert(0, "/home/user")
from log_pipeline import summarize

parsed = [
    {"date": "2024-03-01", "time": "08:00:01", "level": "INFO",  "message": "Starting"},
    {"date": "2024-03-01", "time": "08:15:44", "level": "ERROR", "message": "Timeout"},
    {"date": "2024-03-01", "time": "09:45:03", "level": "ERROR", "message": "NPE"},
    {"date": "2024-03-01", "time": "10:12:55", "level": "WARN",  "message": "Memory high"},
    {"date": "2024-03-01", "time": "11:33:21", "level": "ERROR", "message": "Pool exhausted"},
]

result = summarize(parsed, "app")

if result is None:
    print("NONE")
elif not isinstance(result, dict):
    print("NOT_DICT")
else:
    missing = [k for k in ["service", "errors", "warnings"] if k not in result]
    if missing:
        print("MISSING:" + ",".join(missing))
    else:
        print("OK")
        print(result["service"])
        print(result["errors"])
        print(result["warnings"])
EOF
)

    first_line=$(echo "$result" | head -1)

    if [[ "$first_line" == "NONE" ]]; then
        print_status "failed" "summarize returned None. It must return a dict with keys: service, errors, warnings."
        exit 1
    fi

    if [[ "$first_line" == "NOT_DICT" ]]; then
        print_status "failed" "summarize did not return a dictionary. Return a dict with keys: service, errors, warnings."
        exit 1
    fi

    if [[ "$first_line" == MISSING:* ]]; then
        missing_keys="${first_line#MISSING:}"
        print_status "failed" "summarize is missing key(s): ${missing_keys}. The returned dict must have: service, errors, warnings."
        exit 1
    fi

    service_val=$(echo "$result" | sed -n '2p')
    errors_val=$(echo "$result" | sed -n '3p')
    warns_val=$(echo "$result" | sed -n '4p')

    if [[ "$service_val" != "app" ]]; then
        print_status "failed" "summarize returned service='${service_val}' but expected 'app'. Pass the service_name argument directly into the returned dict."
        exit 1
    fi

    if [[ "$errors_val" != "3" ]]; then
        print_status "failed" "summarize counted ${errors_val} ERROR(s) but expected 3. Count lines where the 'level' key equals 'ERROR'."
        exit 1
    fi

    if [[ "$warns_val" != "1" ]]; then
        print_status "failed" "summarize counted ${warns_val} WARN(s) but expected 1. Count lines where the 'level' key equals 'WARN'."
        exit 1
    fi

    print_status "success" "summarize correctly returned service='app', errors=3, warnings=1."
}

# --------------------------------------------------
# Test 4: full pipeline run produces correct report
# --------------------------------------------------
Test4() {
    if [[ ! -f "$PIPELINE" ]]; then
        print_status "failed" "Pipeline script not found at $PIPELINE."
        exit 1
    fi

    run_output=$(python3 "$PIPELINE" 2>&1)
    run_exit=$?

    if [[ $run_exit -ne 0 ]]; then
        print_status "failed" "log_pipeline.py exited with code $run_exit. Fix both TODOs before running. Output: $(echo "$run_output" | tail -3 | tr '\n' ' ')"
        exit 1
    fi

    if [[ ! -f "$REPORT" ]]; then
        print_status "failed" "Pipeline ran without errors but the report file was not created at $REPORT. Make sure write_report() is being called and that both TODO functions return valid values."
        exit 1
    fi

    total_errors=$(grep -oP 'errors=\K[0-9]+' "$REPORT" | tail -1 || echo "0")
    total_warns=$(grep -oP 'warnings=\K[0-9]+' "$REPORT" | tail -1 || echo "0")

    if [[ "$total_errors" != "7" ]]; then
        print_status "failed" "Report shows total errors=${total_errors} but expected 7 (app=3, db=2, worker=2). Check that parse_log_line correctly extracts the level field and summarize counts ERROR entries."
        exit 1
    fi

    if [[ "$total_warns" != "2" ]]; then
        print_status "failed" "Report shows total warnings=${total_warns} but expected 2 (app=1, worker=1). Check that summarize counts WARN entries."
        exit 1
    fi

    for svc in app db worker; do
        if ! grep -q "$svc" "$REPORT"; then
            print_status "failed" "Report is missing the '${svc}' service line. Ensure summarize is called for every service and its result is passed to write_report."
            exit 1
        fi
    done

    print_status "success" "Pipeline ran end-to-end and produced a correct report: errors=7, warnings=2 across app, db, and worker."
}

Test3
Test4