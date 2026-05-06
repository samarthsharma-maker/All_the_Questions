#!/bin/bash
# ideal_solution2.sh
# Patches the two TODO functions in /home/user/deploy_report.py in-place.
# Run as: bash ideal_solution2.sh

set -euo pipefail

PIPELINE="/home/user/deploy_report.py"

if [[ ! -f "$PIPELINE" ]]; then
    echo "ERROR: $PIPELINE not found. Run the setup script first."
    exit 1
fi

python3 - << 'PYEOF'
PIPELINE = "/home/user/deploy_report.py"

with open(PIPELINE) as f:
    content = f.read()

# ------------------------------------------------------------
# Replace compute_duration stub
# Anchor: pass line + TODO 2 comment + group_by_env def
# ------------------------------------------------------------
old1 = '''    pass  # replace this


# ------------------------------------------------------------
# TODO 2 -- implement this function
# ------------------------------------------------------------
def group_by_env(enriched_rows):'''

new1 = '''    h1, m1, s1 = [int(x) for x in start.split(":")]
    h2, m2, s2 = [int(x) for x in end.split(":")]
    return (h2 * 3600 + m2 * 60 + s2) - (h1 * 3600 + m1 * 60 + s1)


# ------------------------------------------------------------
# TODO 2 -- implement this function
# ------------------------------------------------------------
def group_by_env(enriched_rows):'''

if old1 not in content:
    print("ERROR: Could not locate compute_duration stub. Has the file been edited?")
    raise SystemExit(1)

content = content.replace(old1, new1, 1)

# ------------------------------------------------------------
# Replace group_by_env stub
# Anchor: pass line + already-implemented comment + read_csv def
# ------------------------------------------------------------
old2 = '''    pass  # replace this


# ------------------------------------------------------------
# Already implemented -- do not modify below this line
# ------------------------------------------------------------

def read_csv(filepath):'''

new2 = '''    result = {}
    for row in enriched_rows:
        env = row["env"]
        if env not in result:
            result[env] = {"total": 0, "success": 0, "failed": 0, "_durations": []}
        result[env]["total"] += 1
        result[env][row["status"]] += 1
        result[env]["_durations"].append(row["duration_seconds"])
    for env in result:
        durations = result[env].pop("_durations")
        result[env]["avg_duration_seconds"] = round(sum(durations) / len(durations))
    return result


# ------------------------------------------------------------
# Already implemented -- do not modify below this line
# ------------------------------------------------------------

def read_csv(filepath):'''

if old2 not in content:
    print("ERROR: Could not locate group_by_env stub. Has the file been edited?")
    raise SystemExit(1)

content = content.replace(old2, new2, 1)

with open(PIPELINE, "w") as f:
    f.write(content)

print("Patched deploy_report.py successfully.")
PYEOF

echo "Running pipeline..."
python3 "$PIPELINE"