#!/bin/bash
source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

PROCESS_SCRIPT="/usr/local/bin/databridge-process"

Test3() {
    if [ ! -f "${PROCESS_SCRIPT}" ]; then
        print_status "failed" "Processing script not found at /usr/local/bin/databridge-process."
        return
    fi

    CONTENT=$(cat "${PROCESS_SCRIPT}" | sed 's/#.*//')

    # Check the broken string redirect comparison is gone
    # Pattern: [ "$var" > "$other" ] or [ "$var" > "literal" ]
    if echo "${CONTENT}" | grep -qE '\[\s+"\$[a-zA-Z_]+"\s+>'; then
        print_status "failed" "The processing script uses '>' inside [ ] for a numeric comparison. In bash, '>' inside single brackets is a string redirect operator — it creates a file named after the right-hand operand and always evaluates as true (exit 0). Use '-gt' for integer greater-than comparisons: [ \"\$batch_count\" -gt \"\$THRESHOLD\" ]"
        return
    fi

    # Check -gt is used for the threshold comparison
    if ! echo "${CONTENT}" | grep -qE '\-gt\s+'; then
        print_status "failed" "No integer comparison operator (-gt) found in the processing script. The batch count threshold check must use '-gt' to correctly compare numeric values: if [ \"\$batch_count\" -gt \"\$THRESHOLD\" ]"
        return
    fi

    print_status "success" "Processing script uses '-gt' for integer comparison."
}

Test4() {
    if [ ! -f "${PROCESS_SCRIPT}" ]; then
        print_status "failed" "Processing script not found at /usr/local/bin/databridge-process."
        return
    fi

    CONTENT=$(cat "${PROCESS_SCRIPT}" | sed 's/#.*//')

    # Check pipefail is set — required so pipeline failures don't silently succeed
    if ! echo "${CONTENT}" | grep -qE 'set\s+.*-[a-z]*o\s+pipefail|set\s+.*pipefail|set\s+-[a-z]*[euo]*o\s+pipefail'; then
        # Also catch combined forms like set -euo pipefail
        if ! echo "${CONTENT}" | grep -q 'pipefail'; then
            print_status "failed" "'set -o pipefail' is not set in the processing script. Without pipefail, a failure in the middle of a pipeline (e.g. find ... | while read) is silently ignored — the pipeline exits 0 because bash only checks the last command's exit code. Add 'set -euo pipefail' at the top of the script."
            return
        fi
    fi

    print_status "success" "Processing script enables pipefail, ensuring pipeline failures are not silently swallowed."
}

Test3
Test4