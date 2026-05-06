#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

PIPELINE="/home/user/deploy_report.py"
REPORT="/home/user/deployreports/summary.txt"

Test3() {
    result=$(python3 - << 'EOF'
import sys
sys.path.insert(0, "/home/user")
from deploy_report import group_by_env

rows = [
    {"env": "prod",    "status": "success", "duration_seconds": 270},
    {"env": "prod",    "status": "success", "duration_seconds": 405},
    {"env": "prod",    "status": "failed",  "duration_seconds": 190},
    {"env": "staging", "status": "success", "duration_seconds": 140},
    {"env": "staging", "status": "failed",  "duration_seconds": 170},
    {"env": "staging", "status": "success", "duration_seconds": 180},
    {"env": "dev",     "status": "success", "duration_seconds": 70},
    {"env": "dev",     "status": "success", "duration_seconds": 110},
    {"env": "dev",     "status": "failed",  "duration_seconds": 150},
    {"env": "dev",     "status": "success", "duration_seconds": 80},
]

result = group_by_env(rows)

if result is None:
    print("NONE")
    raise SystemExit(0)

if not isinstance(result, dict):
    print("NOT_DICT")
    raise SystemExit(0)

expected = {
    "prod":    {"total": 3, "success": 2, "failed": 1, "avg_duration_seconds": 288},
    "staging": {"total": 3, "success": 2, "failed": 1, "avg_duration_seconds": 163},
    "dev":     {"total": 4, "success": 3, "failed": 1, "avg_duration_seconds": 102},
}

required_keys = ["total", "success", "failed", "avg_duration_seconds"]

for env, exp in expected.items():
    if env not in result:
        print(f"MISSING_ENV:{env}")
        raise SystemExit(0)
    got = result[env]
    if not isinstance(got, dict):
        print(f"ENV_NOT_DICT:{env}")
        raise SystemExit(0)
    missing_keys = [k for k in required_keys if k not in got]
    if missing_keys:
        print(f"MISSING_KEYS:{env}:{','.join(missing_keys)}")
        raise SystemExit(0)
    for key in required_keys:
        if got[key] != exp[key]:
            print(f"WRONG:{env}:{key}:{exp[key]}:{got[key]}")
            raise SystemExit(0)

print("OK")
EOF
)

    case "$(echo "$result" | head -1)" in
        NONE)
            print_status "failed" "group_by_env returned None. It must return a dict keyed by environment name, each value being a dict with total, success, failed, avg_duration_seconds."
            exit 1
            ;;
        NOT_DICT)
            print_status "failed" "group_by_env did not return a dictionary. Return a dict where each key is an environment name."
            exit 1
            ;;
        MISSING_ENV:*)
            env="${result#MISSING_ENV:}"
            print_status "failed" "group_by_env is missing the '${env}' environment key. Loop over every row and collect all environments dynamically."
            exit 1
            ;;
        ENV_NOT_DICT:*)
            env="${result#ENV_NOT_DICT:}"
            print_status "failed" "The value for environment '${env}' is not a dict. Each environment must map to a dict with total, success, failed, avg_duration_seconds."
            exit 1
            ;;
        MISSING_KEYS:*)
            env=$(echo "$result" | cut -d: -f2)
            keys=$(echo "$result" | cut -d: -f3)
            print_status "failed" "group_by_env result for '${env}' is missing key(s): ${keys}. The inner dict must have exactly: total, success, failed, avg_duration_seconds."
            exit 1
            ;;
        WRONG:*)
            env=$(echo "$result" | cut -d: -f2)
            key=$(echo "$result" | cut -d: -f3)
            expected=$(echo "$result" | cut -d: -f4)
            got=$(echo "$result" | cut -d: -f5)
            print_status "failed" "group_by_env returned ${key}=${got} for '${env}' but expected ${expected}. Check how you are counting or averaging for that field."
            exit 1
            ;;
    esac

    print_status "success" "group_by_env correctly grouped all rows and computed totals, counts, and averages for prod, staging, and dev."
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
        print_status "failed" "deploy_report.py exited with code $run_exit. Fix both TODOs before running. Output: $(echo "$run_output" | tail -3 | tr '\n' ' ')"
        exit 1
    fi

    if [[ ! -f "$REPORT" ]]; then
        print_status "failed" "Pipeline ran without errors but the report file was not created at $REPORT."
        exit 1
    fi

    for env in prod staging dev; do
        if ! grep -q "$env" "$REPORT"; then
            print_status "failed" "Report is missing the '${env}' environment line. Ensure group_by_env handles all environments and write_report iterates over them."
            exit 1
        fi
    done

    if ! grep -qP 'total_deployments=10' "$REPORT"; then
        found=$(grep -oP 'total_deployments=\K[0-9]+' "$REPORT" || echo "0")
        print_status "failed" "Report shows total_deployments=${found} but expected 10. Check that all CSV rows are being read and enriched."
        exit 1
    fi

    if ! grep -qP 'total_failed=3' "$REPORT"; then
        found=$(grep -oP 'total_failed=\K[0-9]+' "$REPORT" || echo "0")
        print_status "failed" "Report shows total_failed=${found} but expected 3. Check that group_by_env is correctly counting failed deployments."
        exit 1
    fi

    for check in "avg_duration_seconds=288" "avg_duration_seconds=163" "avg_duration_seconds=102"; do
        if ! grep -q "$check" "$REPORT"; then
            print_status "failed" "Report is missing '${check}'. Verify compute_duration returns correct seconds and group_by_env rounds the average correctly."
            exit 1
        fi
    done

    print_status "success" "Pipeline ran end-to-end and produced a correct report with all environments, correct counts, and correct average durations."
}

Test3
Test4
