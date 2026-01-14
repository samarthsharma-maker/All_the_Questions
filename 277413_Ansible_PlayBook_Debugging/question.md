# Question 2: YAML Syntax Debugging

## Description

In this lab, you will practice **debugging YAML syntax errors** in Ansible playbooks. YAML is sensitive to indentation, spacing, and structure. Even small mistakes like using tabs instead of spaces, incorrect indentation, or missing colons can cause playbooks to fail.

You are provided with an Ansible **control node** and a **managed node (server1)** along with a **broken playbook** that contains multiple YAML syntax errors. Your task is to identify and fix all errors, validate the syntax, and successfully execute the corrected playbook.

## Tasks

**1. Create a working directory named workspace on the Ansible control node.**

- Set up a dedicated working directory **"/home/user/workspace"** on the Ansible control node.

**2. Create an "inventory.ini" file that defines the managed node (server1) with correct SSH and sudo credentials.**

- The inventory must define the managed node (server1) and include all required connection details so Ansible can:
  - Connect to the remote host over SSH
  - Authenticate using the correct user credentials
  - Escalate privileges when required to perform administrative tasks

**3. A broken playbook file named "broken-playbook.yml" will be provided to you.**

- The playbook contains multiple YAML syntax errors
- Download/copy the provided broken playbook to your workspace directory
- Do NOT create a new playbook from scratch - use the provided file

**4. Identify and fix all YAML syntax errors in the playbook.**

Common errors to look for:
- Incorrect indentation
- Use of tabs instead of spaces
- Missing colons (:)
- Missing dashes (-)
- Improper spacing

**5. Validate the corrected playbook using the syntax-check command.**

- Run: `ansible-playbook broken-playbook.yml --syntax-check`
- The command should return "playbook: broken-playbook.yml" with no errors

**6. Execute the corrected playbook successfully.**

- Run the playbook against the managed node
- Verify all tasks complete without errors

**Required Credentials for the Lab:**

- SSH Credentials: (for remote connection to server1)
  - SSH Username: **`server1_admin`**
  - SSH Password: **`server1_admin@123!`**
- Sudo Credentials (for privilege escalation)
  - Sudo Password: **`server1_admin@123!`**

## Outcomes

After completing this lab, you will be able to:
- Identify common YAML syntax errors in Ansible playbooks
- Understand YAML indentation rules (spaces vs tabs)
- Use the --syntax-check flag to validate playbooks
- Debug and fix broken YAML structures
- Write syntactically correct Ansible playbooks

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

### Step 3: Verify the Provided Broken Playbook

The instructor will provide you with **broken-playbook.yml**. First, let's see what errors exist:

```bash
cat broken-playbook.yml
```

You should see the broken YAML content with multiple syntax errors.

### Step 4: Attempt to Run Syntax Check (It Will Fail)

```bash
ansible-playbook -i inventory.ini broken-playbook.yml --syntax-check
```

**Expected Output (with errors):**
```
ERROR! Syntax Error while loading YAML.
  mapping values are not allowed in this context

The error appears to be in '/home/user/workspace/broken-playbook.yml': line 8, column 15
```

This confirms there are syntax errors that need fixing.

### Step 5: Errors Identified in the Broken Playbook

1. **Line 3-4**: `tasks:` should have proper indentation, and the first task has incorrect indentation
2. **Line 5**: Contains tabs (	) instead of spaces
3. **Line 6-7**: Indentation is incorrect (tabs used)
4. **Line 10**: Missing colon after `file`
5. **Line 11**: Contains tabs instead of spaces
6. **Line 14**: Incorrect indentation for task name
7. **Line 15**: Missing colon after `service`
8. **Line 16**: Missing colon after `name`
9. **Line 17**: Missing colon after `state`

### Step 6: Fix the Broken Playbook

Now, fix all the errors by editing the file or recreating it with correct syntax:

```bash
cat > broken-playbook.yml << 'EOF'
- hosts: web
  become: true
  tasks:
    - name: Install git package
      package:
        name: git
        state: present
  
    - name: Create directory
      file:
        path: /opt/testdir
        state: directory
    
    - name: Start nginx service
      service:
        name: nginx
        state: started
EOF
```

### Step 7: Validate Syntax

```bash
ansible-playbook -i inventory.ini broken-playbook.yml --syntax-check
```

**Expected Output:**
```
playbook: broken-playbook.yml
```

### Step 8: Execute the Corrected Playbook

```bash
ansible-playbook -i inventory.ini broken-playbook.yml
```

**Expected Output:**
```
PLAY [web] *********************************************************************

TASK [Install git package] *****************************************************
changed: [server1]

TASK [Create directory] ********************************************************
changed: [server1]

TASK [Start nginx service] *****************************************************
changed: [server1]

PLAY RECAP *********************************************************************
server1                    : ok=3    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Step 9: Verification Commands

```bash
# Verify git installation
ansible web -i inventory.ini -m command -a "git --version"

# Verify directory creation
ansible web -i inventory.ini -m command -a "ls -ld /opt/testdir"

# Verify nginx service
ansible web -i inventory.ini -m command -a "systemctl status nginx"
```

## Key Learning Points

1. **Always use spaces, never tabs** in YAML files
2. **Indentation must be consistent** - typically 2 spaces per level
3. **Every key-value pair needs a colon** (key: value)
4. **List items start with a dash** followed by a space
5. **Use --syntax-check** before running playbooks in production
6. **Module parameters must be indented** under the module name

---

## INSTRUCTOR RESOURCE: Broken YAML File to Provide to Students

**File: broken-playbook.yml** (Provide this exact file to students)

```yaml
- hosts: web
  become: true
  tasks:
- name: Install git package
	package:
	  name: git
	  state: present
  
  - name: Create directory
   file
	path: /opt/testdir
	state: directory
	
	- name: Start nginx service
	service:
	name: nginx
	state started
```

### Instructions for Instructor:

1. **Save this file with tabs preserved** - The tabs are intentional errors that students must identify
2. **Provide this file to students** at the beginning of the lab
3. Students should NOT create this file from scratch
4. Students must identify and fix all 9 errors in the file

### List of All Errors (For Instructor Reference):

1. **Line 3-4**: `tasks:` has incorrect indentation, first task item not properly aligned
2. **Line 5**: Contains tabs (	) instead of spaces for indentation
3. **Line 6-7**: Module parameters use tabs instead of spaces
4. **Line 10**: Missing colon (`:`) after `file` module name
5. **Line 11**: Contains tabs instead of spaces
6. **Line 12**: Contains tabs instead of spaces  
7. **Line 14**: Incorrect indentation (tabs) for task name
8. **Line 15**: Missing colon (`:`) after `service` module name
9. **Line 16**: Missing colon (`:`) after `name` parameter
10. **Line 17**: Missing colon (`:`) after `state` parameter

### How to Create the File with Tabs:

```bash
# Use this command to create the file with actual tabs
cat > broken-playbook.yml << 'EOF'
- hosts: web
  become: true
  tasks:
- name: Install git package
	package:
	  name: git
	  state: present
  
  - name: Create directory
   file
	path: /opt/testdir
	state: directory
	
	- name: Start nginx service
	service:
	name: nginx
	state started
EOF
```

**Note**: When typing this, press actual TAB key where you see the indentation errors, or copy-paste this directly to preserve tabs.