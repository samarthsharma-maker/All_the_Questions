#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

HARVEST="/home/user/log-harvest"

Test1() {
    if [[ ! -f "$HARVEST" ]]; then
        print_status "failed" "Script not found at /home/user/log-harvest."
        return
    fi

    CONTENT=$(cat "$HARVEST" | sed 's/#.*//')

    # Detect pipe into while loop — the subshell scope bug
    # Pattern: something | while ... read
    if echo "$CONTENT" | grep -qP '^\s*\S.*\|\s*while\b'; then
        print_status "failed" "log-harvest pipes into a while loop. The right-hand side of a pipe runs in a subshell — any variable changes inside the loop (such as incrementing dir_errors or total_errors) are lost when the subshell exits. The error count will always be 0. Fix: use process substitution instead: while IFS= read -r line; do ... done < <(grep -rh 'ERROR' \"\$dir\")"
        return
    fi

    # Confirm process substitution is used
    if ! echo "$CONTENT" | grep -q '< <('; then
        print_status "failed" "log-harvest does not use process substitution for the grep loop. Replace the pipe with process substitution so the loop runs in the current shell and variable changes are preserved: while IFS= read -r line; do ... done < <(grep -rh 'ERROR' \"\$dir\")"
        return
    fi

    print_status "success" "log-harvest uses process substitution for the error-counting loop -- variable scope is preserved."
}

Test2() {
    if [[ ! -f "$HARVEST" ]]; then
        print_status "failed" "Script not found at /home/user/log-harvest."
        return
    fi

    CONTENT=$(cat "$HARVEST" | sed 's/#.*//')

    # Detect the wrong redirect order: 2>&1 >file
    # This pattern redirects stderr to wherever fd1 currently points (terminal),
    # then redirects fd1 to the file -- stderr never reaches the file.
    if echo "$CONTENT" | grep -qE '2>&1\s+>'; then
        print_status "failed" "log-harvest has the redirect order wrong: '2>&1 >file' redirects stderr to the terminal and stdout to the file. Bash processes redirections left to right -- at the point 2>&1 is evaluated, fd1 still points to the terminal. Fix the order: exec >\"\$SCRIPT_LOG\" 2>&1"
        return
    fi

    # Confirm the correct order is present
    if ! echo "$CONTENT" | grep -qE '>\S+\s+2>&1|>"[^"]+"\s+2>&1'; then
        print_status "failed" "log-harvest does not redirect both stdout and stderr to the log file. Use: exec >\"\$SCRIPT_LOG\" 2>&1"
        return
    fi

    print_status "success" "log-harvest correctly redirects stdout then stderr to the log file."
}

Test1
Test2