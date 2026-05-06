#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

SCRIPT_PATH="/home/user/analyze_exam.py"
EXAM_REPORT="/home/user/exam_report.txt"
ERROR_REPORT="/home/user/error_report.txt"
INVALID_EMAILS="/home/user/invalid_emails.txt"


function test_lowest_score() {
    python3 "$SCRIPT_PATH" 2>/dev/null
    
    if ! grep -q "Lowest Score: 72" "$EXAM_REPORT"; then
        print_status "failed" "Exam report does not show correct lowest score (expected: 72)."
        exit 1
    fi
    
    print_status "success" "Lowest score is correct."
}

function test_students_passed() {
    python3 "$SCRIPT_PATH" 2>/dev/null
    
    if ! grep -q "Students Passed.*: 9" "$EXAM_REPORT"; then
        print_status "failed" "Exam report does not show correct passed count (expected: 9)."
        exit 1
    fi
    
    print_status "success" "Students passed count is correct."
}

function test_error_count() {
    python3 "$SCRIPT_PATH" 2>/dev/null
    
    if ! grep -q "Total ERROR entries found: 5" "$ERROR_REPORT"; then
        print_status "failed" "Error report does not show correct error count (expected: 5)."
        exit 1
    fi
    
    print_status "success" "Error count is correct."
}

test_lowest_score
test_students_passed
test_error_count
print_status "success" "Exam report and error report content checks passed. Proceeding to detailed content validation tests."
exit 0
