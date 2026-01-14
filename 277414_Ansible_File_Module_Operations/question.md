# Ansible File Module Operations

## Description

In this lab, you will learn to use the **Ansible file module** to manage files and directories on remote servers. The file module is essential for creating directory structures, setting permissions and ownership, and cleaning up temporary files.

You are provided with an Ansible **control node** and a **managed node (server1)**. Your task is to create a playbook that creates a multi-level directory structure, sets appropriate permissions and ownership, and removes a temporary file.

## Tasks

**1. Create a working directory named workspace on the Ansible control node.**

- Set up a dedicated working directory **"/home/user/workspace"** on the Ansible control node.

**2. Create an "inventory.ini" file that defines the managed node (server1) with correct SSH and sudo credentials.**

- The inventory must define the managed node (server1) and include all required connection details so Ansible can:
  - Connect to the remote host over SSH
  - Authenticate using the correct user credentials
  - Escalate privileges when required to perform administrative tasks

**3. Create an Ansible playbook file named "file-operations.yml"**

In the playbook:
- Target the **web** host group
- Enable privilege escalation using become
- Disable fact gathering
- Create the following directory structure:
  - **/opt/app** (owner: root, group: root, mode: 0755)
  - **/opt/app/logs** (owner: root, group: root, mode: 0755)
  - **/opt/app/config** (owner: root, group: root, mode: 0750)
- Create an empty file at **/opt/app/config/app.conf** (owner: root, group: root, mode: 0644)
- Remove the temporary file at **/tmp/old_file.txt** (if it exists)

**4. Before running the playbook, create a temporary file on server1 to test deletion:**

- Manually create **/tmp/old_file.txt** on server1

**5. Execute the playbook and verify all operations.**

- Run the playbook using ansible-playbook command
- Verify directory creation with correct permissions
- Verify file creation
- Verify temporary file deletion

**Required Credentials for the Lab:**

- SSH Credentials: (for remote connection to server1)
  - SSH Username: **`server1_admin`**
  - SSH Password: **`server1_admin@123!`**
- Sudo Credentials (for privilege escalation)
  - Sudo Password: **`server1_admin@123!`**

## Outcomes

After completing this lab, you will be able to:
- Use the Ansible file module to create directories
- Set file and directory permissions using mode parameter
- Set ownership using owner and group parameters
- Create empty files using the file module
- Remove files and directories using state: absent
- Understand the difference between state: directory, state: file, and state: absent

---

## IDEAL SOLUTION

### Step 1: Create Working Directory

```bash
mkdir -p /home/user/workspace
cd /home/user/workspace
```

### Step 2: Create inventory.ini

```bash
cat > inventory.ini << 'EOF'
[web]
server1 ansible_host=server1 ansible_user=server1_admin ansible_password=server1_admin@123! ansible_become_password=server1_admin@123!
EOF
```

### Step 3: Create Temporary File on server1 (for testing deletion)

```bash
ansible web -i inventory.ini -m shell -a "touch /tmp/old_file.txt"
```

**Expected Output:**
```
server1 | CHANGED | rc=0 >>
```

### Step 4: Create file-operations.yml Playbook

```bash
cat > file-operations.yml << 'EOF'
- hosts: web
  become: true
  gather_facts: false
  tasks:
    - name: Create main application directory
      file:
        path: /opt/app
        state: directory
        owner: root
        group: root
        mode: '0755'
    
    - name: Create logs subdirectory
      file:
        path: /opt/app/logs
        state: directory
        owner: root
        group: root
        mode: '0755'
    
    - name: Create config subdirectory with restricted permissions
      file:
        path: /opt/app/config
        state: directory
        owner: root
        group: root
        mode: '0750'
    
    - name: Create empty configuration file
      file:
        path: /opt/app/config/app.conf
        state: touch
        owner: root
        group: root
        mode: '0644'
    
    - name: Remove temporary file
      file:
        path: /tmp/old_file.txt
        state: absent
EOF
```

### Step 5: Validate Syntax

```bash
ansible-playbook -i inventory.ini file-operations.yml --syntax-check
```

**Expected Output:**
```
playbook: file-operations.yml
```

### Step 6: Execute the Playbook

```bash
ansible-playbook -i inventory.ini file-operations.yml
```

**Expected Output:**
```
PLAY [web] *********************************************************************

TASK [Create main application directory] ***************************************
changed: [server1]

TASK [Create logs subdirectory] ************************************************
changed: [server1]

TASK [Create config subdirectory with restricted permissions] ******************
changed: [server1]

TASK [Create empty configuration file] *****************************************
changed: [server1]

TASK [Remove temporary file] ***************************************************
changed: [server1]

PLAY RECAP *********************************************************************
server1                    : ok=5    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Step 7: Verification Commands

**Verify directory structure and permissions:**

```bash
ansible web -i inventory.ini -m command -a "ls -ld /opt/app"
ansible web -i inventory.ini -m command -a "ls -ld /opt/app/logs"
ansible web -i inventory.ini -m command -a "ls -ld /opt/app/config"
```

**Expected Output:**
```
server1 | CHANGED | rc=0 >>
drwxr-xr-x 4 root root 4096 Dec 29 10:30 /opt/app

server1 | CHANGED | rc=0 >>
drwxr-xr-x 2 root root 4096 Dec 29 10:30 /opt/app/logs

server1 | CHANGED | rc=0 >>
drwxr-x--- 2 root root 4096 Dec 29 10:30 /opt/app/config
```

**Verify file creation:**

```bash
ansible web -i inventory.ini -m command -a "ls -l /opt/app/config/app.conf"
```

**Expected Output:**
```
server1 | CHANGED | rc=0 >>
-rw-r--r-- 1 root root 0 Dec 29 10:30 /opt/app/config/app.conf
```

**Verify temporary file deletion:**

```bash
ansible web -i inventory.ini -m command -a "ls -l /tmp/old_file.txt"
```

**Expected Output:**
```
server1 | FAILED | rc=2 >>
ls: cannot access '/tmp/old_file.txt': No such file or directory
```

### Step 8: Test Idempotency

Run the playbook again:

```bash
ansible-playbook -i inventory.ini file-operations.yml
```

**Expected Output (all tasks should show "ok" instead of "changed"):**
```
PLAY [web] *********************************************************************

TASK [Create main application directory] ***************************************
ok: [server1]

TASK [Create logs subdirectory] ************************************************
ok: [server1]

TASK [Create config subdirectory with restricted permissions] ******************
ok: [server1]

TASK [Create empty configuration file] *****************************************
ok: [server1]

TASK [Remove temporary file] ***************************************************
ok: [server1]

PLAY RECAP *********************************************************************
server1                    : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

## Key Learning Points

1. **state: directory** - Creates directories (and parent directories if needed)
2. **state: touch** - Creates empty files or updates timestamps
3. **state: absent** - Removes files or directories
4. **mode parameter** - Sets file/directory permissions (use quotes: '0755')
   - 0755 = rwxr-xr-x (owner: rwx, group: rx, others: rx)
   - 0750 = rwxr-x--- (owner: rwx, group: rx, others: none)
   - 0644 = rw-r--r-- (owner: rw, group: r, others: r)
5. **owner and group** - Set file/directory ownership
6. **Idempotency** - Running the playbook multiple times produces the same result
7. **file module is safe** - It only makes changes when needed

## Permission Mode Guide

| Mode | Binary | Permission | Usage |
|------|--------|------------|-------|
| 0755 | 111 101 101 | rwxr-xr-x | Directories, executables |
| 0750 | 111 101 000 | rwxr-x--- | Restricted directories |
| 0644 | 110 100 100 | rw-r--r-- | Regular files |
| 0600 | 110 000 000 | rw------- | Sensitive files |