# Linux User and File System Audit Tool

## Description
In this lab, you will build a system audit script that performs two categories of checks on a Linux system: detecting files and directories with no valid owning user, and auditing sudo privileges across all users. You will develop a bash script called `sys_audit.sh` that writes a structured audit report to `/home/user/audit_report.txt`.

The script relies on `/etc/passwd`, `find`, and `sudo` inspection techniques commonly used in real DevOps and sysadmin workflows.

**Notice**: Use `Ctrl + C` instead of `Esc`

---

## Objectives
- Use `find` with `-nouser` to detect orphaned files
- Inspect sudo privileges using `/etc/sudoers` and `/etc/sudoers.d/`
- Produce a structured multi-section audit report in bash

---

## Outcomes
- Learners will demonstrate the ability to query filesystem ownership metadata
- Learners will audit privilege configurations from system files
- Learners will format multi-section structured reports from raw system data

---

## Tasks

### Task 1 -- Orphaned File Detection
Create a bash script named `sys_audit.sh` in `/home/user/`. The script takes no arguments.

When invoked, the script must scan the `/home/user/audit_zone/` directory for files and directories that have no valid owning user (i.e., the UID does not correspond to any entry in `/etc/passwd`). Write the results to `/home/user/audit_report.txt` under the following section header:
```
[ORPHANED FILES]
/audit_zone/some_file
/audit_zone/another_dir
```

If no orphaned files are found, write:
```
[ORPHANED FILES]
NONE
```

**Note**: Use `find /home/user/audit_zone -nouser` to identify orphaned entries.

---

### Task 2 -- Sudo Privilege Audit
Extend `sys_audit.sh` to audit sudo privileges across all non-system users. For each user account with UID 1000 or above (excluding `nobody`), check whether they have sudo access by inspecting `/etc/sudoers` and all files under `/etc/sudoers.d/`.

Append the results to `/home/user/audit_report.txt` under this section header:
```
[SUDO AUDIT]
alice  SUDO:YES
bob  SUDO:NO
charlie  SUDO:YES
```
List all qualifying users alphabetically. If no qualifying users exist, write:
```
[SUDO AUDIT]
NONE
```

If a user has any entry granting them sudo privileges, mark them as `SUDO:YES`. If they have no sudo privileges, mark them as `SUDO:NO`.

Each user entry is on its own separate line with 2 spaces between the username and the SUDO status.

**Note**: For this lab, check only direct username matches in sudoers files (group-based sudo is not required).

---

## Implementation Notes

### Script Requirements
- **File name**: `sys_audit.sh`
- **Location**: `/home/user/`
- **Arguments**: None
- **Output file**: `/home/user/audit_report.txt`
- **Scan target**: `/home/user/audit_zone/` for orphaned files

### Section Format
Each section must begin with its header on its own line, followed by one entry per line. Sections must appear in this order:
1. `[ORPHANED FILES]`
2. `[SUDO AUDIT]`

### Key Commands
- **Orphaned files**: `find /home/user/audit_zone -nouser`
- **Sudoers check**: `grep -r "^<username>" /etc/sudoers /etc/sudoers.d/`

### Output File
The script must overwrite `/home/user/audit_report.txt` on each run, not append to a previous run.