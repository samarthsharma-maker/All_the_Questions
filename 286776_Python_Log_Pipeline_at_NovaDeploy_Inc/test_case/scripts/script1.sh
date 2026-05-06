#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

PIPELINE="/home/user/log_pipeline.py"
REPORT="/home/user/logreports/summary.txt"


Test1() {
    if [[ ! -f "$PIPELINE" ]]; then
        print_status "failed" "Pipeline script not found at $PIPELINE."
        return
    fi

    result=$(python3 - << 'EOF'
import sys
sys.path.insert(0, "/home/user")
from log_pipeline import parse_log_line

line = "2024-03-01 08:15:44 ERROR Failed to process request: timeout after 30s"
result = parse_log_line(line)

if result is None:
    print("NONE")
elif not isinstance(result, dict):
    print("NOT_DICT")
else:
    missing = [k for k in ["date", "time", "level", "message"] if k not in result]
    if missing:
        print("MISSING:" + ",".join(missing))
    else:
        print("OK")
        print(result["date"])
        print(result["time"])
        print(result["level"])
        print(result["message"])
EOF
)

    first_line=$(echo "$result" | head -1)

    if [[ "$first_line" == "NONE" ]]; then
        print_status "failed" "parse_log_line returned None for a valid log line. Make sure you return a dict, not None, when the line is well-formed."
        exit 1
    fi

    if [[ "$first_line" == "NOT_DICT" ]]; then
        print_status "failed" "parse_log_line did not return a dictionary. The function must return a dict with keys: date, time, level, message."
        exit 1
    fi

    if [[ "$first_line" == MISSING:* ]]; then
        missing_keys="${first_line#MISSING:}"
        print_status "failed" "parse_log_line returned a dict but is missing key(s): ${missing_keys}. Expected keys are: date, time, level, message."
        exit 1
    fi

    date_val=$(echo "$result" | sed -n '2p')
    time_val=$(echo "$result" | sed -n '3p')
    level_val=$(echo "$result" | sed -n '4p')
    msg_val=$(echo "$result" | sed -n '5p')

    if [[ "$date_val" != "2024-03-01" ]]; then
        print_status "failed" "parse_log_line returned date='${date_val}' but expected '2024-03-01'. Split on whitespace and assign the first token to 'date'."
        exit 1
    fi

    if [[ "$time_val" != "08:15:44" ]]; then
        print_status "failed" "parse_log_line returned time='${time_val}' but expected '08:15:44'. The second token is the time."
        exit 1
    fi

    if [[ "$level_val" != "ERROR" ]]; then
        print_status "failed" "parse_log_line returned level='${level_val}' but expected 'ERROR'. The third token is the log level."
        exit 1
    fi

    if [[ "$msg_val" != "Failed to process request: timeout after 30s" ]]; then
        print_status "failed" "parse_log_line returned message='${msg_val}' but expected 'Failed to process request: timeout after 30s'. Use maxsplit=3 so spaces inside the message are preserved."
        exit 1
    fi

    print_status "success" "parse_log_line correctly parsed date, time, level, and message from a valid log line."
}


Test2() {
    result=$(python3 - << 'EOF'
import sys
sys.path.insert(0, "/home/user")
from log_pipeline import parse_log_line

short_line = "2024-03-01 INFO"
result = parse_log_line(short_line)
print("NONE" if result is None else "NOT_NONE")
EOF
)

    if [[ "$result" != "NONE" ]]; then
        print_status "failed" "parse_log_line should return None when a line has fewer than 4 parts, but it returned a value. Add a length check before building the dict."
        exit 1
    fi

    print_status "success" "parse_log_line correctly returns None for a malformed log line with fewer than 4 parts."
}

Test1
Test2