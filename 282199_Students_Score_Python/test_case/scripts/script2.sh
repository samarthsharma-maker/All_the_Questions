#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

SCRIPT_PATH="/home/user/analyze_exam.py"
EXAM_REPORT="/home/user/exam_report.txt"
ERROR_REPORT="/home/user/error_report.txt"
INVALID_EMAILS="/home/user/invalid_emails.txt"

function test_total_students() {
    python3 "$SCRIPT_PATH" 2>/dev/null
    
    if ! grep -q "Total Students: 10" "$EXAM_REPORT"; then
        print_status "failed" "Exam report does not show correct total students (expected: 10)."
        exit 1
    fi
    
    print_status "success" "Total students count is correct."
}

function test_average_score() {
    python3 "$SCRIPT_PATH" 2>/dev/null
    
    if ! grep -E "Average Score: 85\.3" "$EXAM_REPORT"; then
        print_status "failed" "Exam report does not show correct average score (expected: 85.3 or 85.30)."
        exit 1
    fi
    
    print_status "success" "Average score calculation is correct."
}

function test_highest_score() {
    python3 "$SCRIPT_PATH" 2>/dev/null
    
    if ! grep -q "Highest Score: 95" "$EXAM_REPORT"; then
        print_status "failed" "Exam report does not show correct highest score (expected: 95)."
        exit 1
    fi
    
    print_status "success" "Highest score is correct."
}

test_total_students
test_average_score
test_highest_score

print_status "success" "metrics in exam report are correct."
exit 0