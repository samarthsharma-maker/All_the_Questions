#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

SCRIPT_PATH="/home/user/analyze_exam.py"
EXAM_REPORT="/home/user/exam_report.txt"
ERROR_REPORT="/home/user/error_report.txt"
INVALID_EMAILS="/home/user/invalid_emails.txt"
# Write your test logic here
function test_error_details_present() {
    python3 "$SCRIPT_PATH" 2>/dev/null
    
    if ! grep -q "Student 103 authentication failed" "$ERROR_REPORT"; then
        print_status "failed" "Error report missing expected error line about Student 103."
        exit 1
    fi
    
    if ! grep -q "Student 111 authentication failed" "$ERROR_REPORT"; then
        print_status "failed" "Error report missing expected error line about Student 111."
        exit 1
    fi
    print_status "success" "Error details are present in error report."
}

function test_all_errors_listed() {
    python3 "$SCRIPT_PATH" 2>/dev/null
    
    error_count=$(grep -c "ERROR" "$ERROR_REPORT" | tail -1)
    
    if [ "$error_count" -lt 5 ]; then
        print_status "failed" "Error report does not list all 5 error entries."
        exit 1
    fi
    print_status "success" "All error entries are listed in error report."
}

function test_invalid_email_student_104() {
    python3 "$SCRIPT_PATH" 2>/dev/null
    
    if ! grep -q "104" "$INVALID_EMAILS"; then
        print_status "failed" "Invalid emails report missing Student ID 104."
        exit 1
    fi
    
    if ! grep -q "diana.invalid-email" "$INVALID_EMAILS"; then
        print_status "failed" "Invalid emails report missing email 'diana.invalid-email'."
        exit 1
    fi
    print_status "success" "Student 104's invalid email correctly identified."
}

test_error_details_present
test_all_errors_listed
test_invalid_email_student_104
print_status "success" "Error report and invalid email report content checks passed. Proceeding to metrics validation tests."
exit 0