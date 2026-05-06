#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

PIPELINE="/home/user/deploy_report.py"
REPORT="/home/user/deployreports/summary.txt"

# --------------------------------------------------
# Test 1: compute_duration returns correct seconds
# --------------------------------------------------
Test1() {
    if [[ ! -f "$PIPELINE" ]]; then
        print_status "failed" "Pipeline script not found at $PIPELINE."
        return
    fi

    result=$(python3 - << 'EOF'
import sys
sys.path.insert(0, "/home/user")
from deploy_report import compute_duration

cases = [
    ("08:00:00", "08:04:30", 270),
    ("09:15:00", "09:21:45", 405),
    ("00:00:00", "00:01:00", 60),
    ("00:00:00", "01:00:00", 3600),
    ("10:30:00", "10:33:10", 190),
]

for start, end, expected in cases:
    got = compute_duration(start, end)
    if got is None:
        print(f"NONE:{start}:{end}:{expected}")
    elif not isinstance(got, int):
        print(f"NOTINT:{start}:{end}:{expected}:{type(got).__name__}")
    elif got != expected:
        print(f"WRONG:{start}:{end}:{expected}:{got}")
    else:
        print(f"OK:{start}:{end}:{expected}")
EOF
)

    while IFS= read -r line; do
        tag=$(echo "$line" | cut -d: -f1)
        start=$(echo "$line" | cut -d: -f2)
        end=$(echo "$line" | cut -d: -f3)
        expected=$(echo "$line" | cut -d: -f4)

        case "$tag" in
            NONE)
                print_status "failed" "compute_duration(\"${start}\", \"${end}\") returned None. The function must return an integer number of seconds, not None."
                return
                ;;
            NOTINT)
                got_type=$(echo "$line" | cut -d: -f5)
                print_status "failed" "compute_duration(\"${start}\", \"${end}\") returned a ${got_type} instead of an int. Convert each time part with int() and return a plain integer."
                return
                ;;
            WRONG)
                got=$(echo "$line" | cut -d: -f5)
                print_status "failed" "compute_duration(\"${start}\", \"${end}\") returned ${got} but expected ${expected}. Check your seconds conversion: hours * 3600 + minutes * 60 + seconds, then subtract start from end."
                return
                ;;
        esac
    done <<< "$result"

    print_status "success" "compute_duration correctly converts HH:MM:SS pairs to seconds across all test cases."
}

# --------------------------------------------------
# Test 2: compute_duration handles hour boundaries
# --------------------------------------------------
Test2() {
    result=$(python3 - << 'EOF'
import sys
sys.path.insert(0, "/home/user")
from deploy_report import compute_duration

cases = [
    ("07:30:00", "07:31:10", 70),
    ("08:45:00", "08:46:50", 110),
    ("13:00:00", "13:01:20", 80),
]

for start, end, expected in cases:
    got = compute_duration(start, end)
    if got != expected:
        print(f"WRONG:{start}:{end}:{expected}:{got}")
    else:
        print(f"OK:{start}:{end}:{expected}")
EOF
)

    while IFS= read -r line; do
        tag=$(echo "$line" | cut -d: -f1)
        if [[ "$tag" == "WRONG" ]]; then
            start=$(echo "$line" | cut -d: -f2)
            end=$(echo "$line" | cut -d: -f3)
            expected=$(echo "$line" | cut -d: -f4)
            got=$(echo "$line" | cut -d: -f5)
            print_status "failed" "compute_duration(\"${start}\", \"${end}\") returned ${got} but expected ${expected}. Make sure you are splitting on \":\" and converting all three parts -- hours, minutes, and seconds -- before computing the total."
            exit 1
        fi
    done <<< "$result"

    print_status "success" "compute_duration correctly handles sub-minute and multi-minute durations."
}


Test1
Test2
