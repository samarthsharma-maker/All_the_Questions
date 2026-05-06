#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

SCRIPT_PATH="/home/user/analyze_exam.py"
EXAM_REPORT="/home/user/exam_report.txt"
ERROR_REPORT="/home/user/error_report.txt"
INVALID_EMAILS="/home/user/invalid_emails.txt"

function test_script_exists() {
    if [ ! -f "$SCRIPT_PATH" ]; then
        print_status "failed" "Script 'analyze_exam.py' does not exist."
        exit 1
    fi
    print_status "success" "Script exists."
}

function test_script_shebang() {
    if ! head -n 1 "$SCRIPT_PATH" | grep -q "#!/usr/bin/env python3"; then
        print_status "failed" "Script does not have correct shebang '#!/usr/bin/env python3'."
        exit 1
    fi
    print_status "success" "Script has correct shebang."
}

function test_output_files_created() {
    rm -f "$EXAM_REPORT" "$ERROR_REPORT" "$INVALID_EMAILS"    
    python3 "$SCRIPT_PATH" 2>/dev/null
    
    if [ ! -f "$EXAM_REPORT" ]; then
        print_status "failed" "Output file 'exam_report.txt' was not created."
        exit 1
    fi
    
    if [ ! -f "$ERROR_REPORT" ]; then
        print_status "failed" "Output file 'error_report.txt' was not created."
        exit 1
    fi
    
    if [ ! -f "$INVALID_EMAILS" ]; then
        print_status "failed" "Output file 'invalid_emails.txt' was not created."
        exit 1
    fi
    
    print_status "success" "All three output files created successfully."
}


test_script_exists
test_script_shebang
test_output_files_created
print_status "success" "Basic script checks passed. Proceeding to content validation tests."
exit 0
