Here's the cleaned-up version:

---

# The Phantom Breach -- NovaPay Security Audit

## Scenario

NovaPay, a fast-growing fintech startup in Bangalore, recently survived a serious security scare. During a routine deployment, their on-call SRE noticed zombie processes left behind by a poorly written payment worker accumulating silently in the process table. Each zombie held a slot open and masked the parent process that had spawned it, making it difficult to trace which service was misbehaving during the incident window.

The security team has tasked you with writing a focused audit script to detect and report these zombie processes so the on-call engineer can review findings each morning or ship them directly to the team's SIEM.

---

## Objective

Detect zombie processes by reading `/proc` and report each one alongside its parent process name.

---

## Task -- Zombie Process Detection

Write a bash script named `zombie_audit.sh` inside `/home/user/`.

The script takes no arguments. When run, it must scan all currently running processes and identify any that are in the zombie state (`Z`). For each zombie found, report its PID and the name of its parent process.

The script must write its output to `/home/user/zombie_report.txt`, overwriting the file on each run, using the following format:

```
[ZOMBIE PROCESSES]
PID:1234 
PARENT:payment_worker

PID:5678 
PARENT:watchdog
```

If no zombies are found, write:

```
[ZOMBIE PROCESSES]
NONE
```

**Note**: Read `/proc/<pid>/status` to check the `State` field for `Z` and the `PPid` field to get the parent PID. Then read `/proc/<ppid>/status` and extract the `Name` field to resolve the parent process name.

---

## Script Summary

| Script | Report File |
|---|---|
| `zombie_audit.sh` | `zombie_report.txt` |

The script must live in `/home/user/` and overwrite its report file on every run.