# Ansible User Management Complete Workflow

## Description

In this lab, you will learn to use the **Ansible user module** to manage user accounts on remote servers. User management is a critical DevOps task - creating accounts for new team members, setting proper shells, managing home directories, and removing accounts when employees leave.

You are provided with an Ansible **control node** and a **managed node (server1)**. Your task is to create a playbook that creates multiple users with specific configurations and removes an old test user.

## Tasks

**1. Create a working directory named workspace on the Ansible control node.**

- Set up a dedicated working directory **"/home/user/workspace"** on the Ansible control node.

**2. Create an "inventory.ini" file that defines the managed node (server1) with correct SSH and sudo credentials.**

- The inventory must define the managed node (server1) and include all required connection details so Ansible can:
  - Connect to the remote host over SSH
  - Authenticate using the correct user credentials
  - Escalate privileges when required to perform administrative tasks

**3. Verify the existing test user on server1:**

- A user named **olduser** already exists on server1 (provided in lab setup)
- This simulates a real-world scenario where an old employee's account needs to be removed
- You can verify its existence before starting

**4. Create an Ansible playbook file named "user-management.yml"**

In the playbook:
- Target the **web** host group
- Enable privilege escalation using become
- Disable fact gathering
- Create the following users with home directories and bash shell:
  - **dev1** (Development user)
  - **dev2** (Development user)
  - **admin** (Administrator user)
- All users should have:
  - Home directories created automatically
  - Shell set to **/bin/bash**
  - state: present
- Remove the user **olduser** completely (including home directory)

**5. Execute the playbook and verify user creation and deletion.**

- Run the playbook using ansible-playbook command
- Verify all users are created with proper shells
- Verify home directories exist
- Verify olduser is removed

**Required Credentials for the Lab:**

- SSH Credentials: (for remote connection to server1)
  - SSH Username: **`server1_admin`**
  - SSH Password: **`server1_admin@123!`**
- Sudo Credentials (for privilege escalation)
  - Sudo Password: **`server1_admin@123!`**

## Outcomes

After completing this lab, you will be able to:
- Use the Ansible user module to create user accounts
- Configure user shells and home directories
- Remove users safely using Ansible
- Understand the difference between state: present and state: absent
- Manage user accounts in an idempotent and auditable way
- Implement real-world user provisioning and deprovisioning workflows

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

### Step 3: Verify Existing Test User (olduser) on server1

The lab environment has already created a user called **olduser**. Let's verify it exists:

```bash
ansible web -i inventory.ini -m command -a "id olduser"
```

**Expected Output:**
```
server1 | CHANGED | rc=0 >>
uid=1001(olduser) gid=1001(olduser) groups=1001(olduser)
```

This confirms the user exists and will be removed by our playbook.

### Step 4: Create user-management.yml Playbook

```bash
cat > user-management.yml << 'EOF'
- hosts: web
  become: true
  gather_facts: false
  tasks:
    - name: Create dev1 user with home directory
      user:
        name: dev1
        state: present
        shell: /bin/bash
        create_home: true
    
    - name: Create dev2 user with home directory
      user:
        name: dev2
        state: present
        shell: /bin/bash
        create_home: true
    
    - name: Create admin user with home directory
      user:
        name: admin
        state: present
        shell: /bin/bash
        create_home: true
    
    - name: Remove olduser completely
      user:
        name: olduser
        state: absent
        remove: true
EOF
```

### Step 5: Validate Syntax

```bash
ansible-playbook -i inventory.ini user-management.yml --syntax-check
```

**Expected Output:**
```
playbook: user-management.yml
```

### Step 6: Execute the Playbook

```bash
ansible-playbook -i inventory.ini user-management.yml
```

**Expected Output:**
```
PLAY [web] *********************************************************************

TASK [Create dev1 user with home directory] ************************************
changed: [server1]

TASK [Create dev2 user with home directory] ************************************
changed: [server1]

TASK [Create admin user with home directory] ***********************************
changed: [server1]

TASK [Remove olduser completely] ***********************************************
changed: [server1]

PLAY RECAP *********************************************************************
server1                    : ok=4    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Step 7: Verification Commands

**Verify dev1 user creation:**

```bash
ansible web -i inventory.ini -m command -a "id dev1"
```

**Expected Output:**
```
server1 | CHANGED | rc=0 >>
uid=1002(dev1) gid=1002(dev1) groups=1002(dev1)
```

**Verify dev2 user creation:**

```bash
ansible web -i inventory.ini -m command -a "id dev2"
```

**Expected Output:**
```
server1 | CHANGED | rc=0 >>
uid=1003(dev2) gid=1003(dev2) groups=1003(dev2)
```

**Verify admin user creation:**

```bash
ansible web -i inventory.ini -m command -a "id admin"
```

**Expected Output:**
```
server1 | CHANGED | rc=0 >>
uid=1004(admin) gid=1004(admin) groups=1004(admin)
```

**Verify user shells:**

```bash
ansible web -i inventory.ini -m command -a "grep -E 'dev1|dev2|admin' /etc/passwd"
```

**Expected Output:**
```
server1 | CHANGED | rc=0 >>
dev1:x:1002:1002::/home/dev1:/bin/bash
dev2:x:1003:1003::/home/dev2:/bin/bash
admin:x:1004:1004::/home/admin:/bin/bash
```

**Verify home directories exist:**

```bash
ansible web -i inventory.ini -m command -a "ls -ld /home/dev1 /home/dev2 /home/admin"
```

**Expected Output:**
```
server1 | CHANGED | rc=0 >>
drwxr-x--- 2 dev1 dev1 4096 Dec 29 11:00 /home/dev1
drwxr-x--- 2 dev2 dev2 4096 Dec 29 11:00 /home/dev2
drwxr-x--- 2 admin admin 4096 Dec 29 11:00 /home/admin
```

**Verify olduser was removed:**

```bash
ansible web -i inventory.ini -m command -a "id olduser"
```

**Expected Output:**
```
server1 | FAILED | rc=1 >>
id: 'olduser': no such user
```

**Verify olduser home directory was removed:**

```bash
ansible web -i inventory.ini -m command -a "ls -ld /home/olduser"
```

**Expected Output:**
```
server1 | FAILED | rc=2 >>
ls: cannot access '/home/olduser': No such file or directory
```

### Step 8: Test Idempotency

Run the playbook again:

```bash
ansible-playbook -i inventory.ini user-management.yml
```

**Expected Output (tasks should show "ok" instead of "changed"):**
```
PLAY [web] *********************************************************************

TASK [Create dev1 user with home directory] ************************************
ok: [server1]

TASK [Create dev2 user with home directory] ************************************
ok: [server1]

TASK [Create admin user with home directory] ***********************************
ok: [server1]

TASK [Remove olduser completely] ***********************************************
ok: [server1]

PLAY RECAP *********************************************************************
server1                    : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Step 9: Additional Verification - Check User Details

```bash
ansible web -i inventory.ini -m command -a "getent passwd dev1"
```

**Expected Output:**
```
server1 | CHANGED | rc=0 >>
dev1:x:1002:1002::/home/dev1:/bin/bash
```

## Key Learning Points

1. **user module** - Primary module for managing user accounts in Ansible
2. **state: present** - Ensures user exists
3. **state: absent** - Removes user account
4. **create_home: true** - Automatically creates home directory
5. **shell parameter** - Sets the user's login shell
6. **remove: true** - When removing user, also removes home directory
7. **Idempotency** - Safe to run multiple times
8. **Audit-friendly** - All changes are logged and traceable

## User Module Parameters Reference

| Parameter | Description | Values |
|-----------|-------------|--------|
| name | Username | String |
| state | User state | present, absent |
| shell | Login shell | /bin/bash, /bin/sh, etc. |
| create_home | Create home directory | true, false |
| remove | Remove home on deletion | true, false |
| groups | Additional groups | List of groups |
| append | Append to groups | true, false |
| password | User password (hashed) | Hashed password string |

## Real-World Use Cases

1. **Onboarding**: Create accounts for new developers/employees
2. **Offboarding**: Remove accounts when employees leave
3. **Standardization**: Ensure all servers have consistent user configurations
4. **Automation**: Integrate with HR systems for automated user lifecycle management
5. **Security**: Enforce shell restrictions and home directory permissions

---

## LAB SETUP REQUIREMENT (For Instructor/Lab Admin)

Before students start this lab, the following setup must be completed on **server1**:

### Create the olduser account:

```bash
# On server1 or via Ansible from control node
sudo useradd -m -s /bin/bash olduser
```

**Or using Ansible ad-hoc command:**

```bash
ansible server1 -i inventory.ini -m user -a "name=olduser state=present create_home=yes shell=/bin/bash" --become
```

**Verify the user was created:**

```bash
id olduser
ls -ld /home/olduser
```
