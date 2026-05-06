#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

SCRIPT_PATH="/home/user/analyze_exam.py"
EXAM_REPORT="/home/user/exam_report.txt"
ERROR_REPORT="/home/user/error_report.txt"
INVALID_EMAILS="/home/user/invalid_emails.txt"


function test_invalid_email_student_108() {
    python3 "$SCRIPT_PATH" 2>/dev/null
    
    if ! grep -q "108" "$INVALID_EMAILS"; then
        print_status "failed" "Invalid emails report missing Student ID 108."
        exit 1
    fi
    
    if ! grep -q "henry@university" "$INVALID_EMAILS"; then
        print_status "failed" "Invalid emails report missing email 'henry@university'."
        exit 1
    fi
    print_status "success" "Student 108's invalid email correctly identified."
}

function test_valid_emails_not_included() {
    python3 "$SCRIPT_PATH" 2>/dev/null
    
    if grep -q "alice.smith@university.edu" "$INVALID_EMAILS"; then
        print_status "failed" "Invalid emails report incorrectly includes valid email 'alice.smith@university.edu'."
        exit 1
    fi
    
    if grep -q "Student ID 101" "$INVALID_EMAILS"; then
        print_status "failed" "Invalid emails report incorrectly includes Student 101 who has valid email."
        exit 1
    fi
    
    print_status "success" "Valid emails correctly excluded from invalid emails report."
}

function test_no_external_imports() {
    if grep -E "^import (numpy|pandas|requests|matplotlib)" "$SCRIPT_PATH"; then
        print_status "failed" "Script imports external libraries (only built-in libraries allowed)."
        exit 1
    fi
    
    print_status "success" "Script does not import external libraries."
}

test_invalid_email_student_108
test_valid_emails_not_included
test_no_external_imports

print_status "success" "All tests passed successfully!"
exit 0
