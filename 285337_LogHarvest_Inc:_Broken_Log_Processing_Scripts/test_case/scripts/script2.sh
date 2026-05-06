#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

REPORT="/home/user/log-report"

Test3() {
    if [[ ! -f "$REPORT" ]]; then
        print_status "failed" "Script not found at /home/user/log-report."
        return
    fi

    CONTENT=$(cat "$REPORT" | sed 's/#.*//')

    # Detect unquoted array expansion in a for loop
    # Pattern: for <var> in ${arr[@]} or ${arr[*]} without surrounding quotes
    if echo "$CONTENT" | grep -qP 'for\s+\w+\s+in\s+\$\{?\w+\[@\]\}?(?!\s*;)' || \
       echo "$CONTENT" | grep -qP 'for\s+\w+\s+in\s+\$\{\w+\[@\]\}[^"]'; then
        print_status "failed" "log-report iterates over an array without quoting the expansion: \${arr[@]}. Without double quotes, bash performs word splitting on each element -- any path containing a space is broken into separate tokens and neither resolves correctly. Fix: for dir in \"\${report_dirs[@]}\"; do"
        return
    fi

    # Check quoted form is present
    if ! echo "$CONTENT" | grep -qP 'for\s+\w+\s+in\s+"\$\{?\w+\[@\]\}?"'; then
        print_status "failed" "log-report does not iterate over the report_dirs array with a quoted expansion. Use: for dir in \"\${report_dirs[@]}\"; do"
        return
    fi

    print_status "success" "log-report correctly uses \"\${report_dirs[@]}\" to iterate the array without word splitting."
}

Test4() {
    if [[ ! -f "$REPORT" ]]; then
        print_status "failed" "Script not found at /home/user/log-report."
        return
    fi

    CONTENT=$(cat "$REPORT" | sed 's/#.*//')

    # Check that the read loop does NOT use a pipe into while.
    # A pipe runs the loop in a subshell -- total_errors, total_warns,
    # and line_count are all reset to 0 in the parent shell after the loop.
    if echo "$CONTENT" | grep -qP 'tail\s+-n\s+\+\d+\s+.*\|\s*while\b|^\s*\S.*\|\s*while\b.*read'; then
        print_status "failed" "log-report pipes into the read loop. The loop runs in a subshell and all counter variables (line_count, total_errors, total_warns) are lost after it exits -- totals will always print as 0. Use process substitution to keep the loop in the current shell: while IFS=',' read -r service date errors warns || [[ -n "${service:-}" ]]; do ... done < <(tail -n +2 \"\$CSV_FILE\")"
        return
    fi

    # Check process substitution is used
    if ! echo "$CONTENT" | grep -q '< <('; then
        print_status "failed" "log-report does not use process substitution for the CSV read loop. Replace the pipe with: done < <(tail -n +2 \"\$CSV_FILE\")"
        return
    fi

    # Check the last-line guard is present — accept $service or ${service:-}
    if ! echo "$CONTENT" | grep -qP 'read.*\|\|\s*\[\[.*-n.*\$\{?service'; then
        print_status "failed" "log-report is missing the EOF guard on the read loop. When the CSV has no trailing newline, 'read' returns non-zero on the last line even though it populated the variables -- that line is silently skipped. Fix: while IFS=',' read -r service date errors warns || [[ -n "${service:-}" ]]; do"
        return
    fi

    print_status "success" "log-report uses process substitution for the read loop and guards against files without a trailing newline."
}

Test3
Test4