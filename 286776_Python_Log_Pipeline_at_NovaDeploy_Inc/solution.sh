#!/bin/bash
# ideal_solution.sh
# Patches the two TODO functions in /home/user/log_pipeline.py in-place.
# Run as: bash ideal_solution.sh

set -euo pipefail

PIPELINE="/home/user/log_pipeline.py"

if [[ ! -f "$PIPELINE" ]]; then
    echo "ERROR: $PIPELINE not found. Run the setup script first."
    exit 1
fi

python3 - << 'PYEOF'
PIPELINE = "/home/user/log_pipeline.py"

with open(PIPELINE, "r") as f:
    content = f.read()

# ------------------------------------------------------------
# Replace parse_log_line stub
# ------------------------------------------------------------
old_parse = '''    pass  # replace this


# ------------------------------------------------------------
# TODO 2 -- implement this function'''

new_parse = '''    parts = line.split(None, 3)
    if len(parts) < 4:
        return None
    return {
        "date":    parts[0],
        "time":    parts[1],
        "level":   parts[2],
        "message": parts[3],
    }


# ------------------------------------------------------------
# TODO 2 -- implement this function'''

if old_parse not in content:
    print("ERROR: Could not find parse_log_line stub. Has the file been modified?")
    raise SystemExit(1)

content = content.replace(old_parse, new_parse, 1)

# ------------------------------------------------------------
# Replace summarize stub
# ------------------------------------------------------------
old_summarize = '''    pass  # replace this


# ------------------------------------------------------------
# Already implemented -- do not modify below this line'''

new_summarize = '''    errors   = sum(1 for p in parsed_lines if p["level"] == "ERROR")
    warnings = sum(1 for p in parsed_lines if p["level"] == "WARN")
    return {
        "service":  service_name,
        "errors":   errors,
        "warnings": warnings,
    }


# ------------------------------------------------------------
# Already implemented -- do not modify below this line'''

if old_summarize not in content:
    print("ERROR: Could not find summarize stub. Has the file been modified?")
    raise SystemExit(1)

content = content.replace(old_summarize, new_summarize, 1)

with open(PIPELINE, "w") as f:
    f.write(content)

print("Patched log_pipeline.py successfully.")
PYEOF

echo "Running pipeline..."
python3 "$PIPELINE"