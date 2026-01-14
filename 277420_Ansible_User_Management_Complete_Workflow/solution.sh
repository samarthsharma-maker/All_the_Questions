#!/bin/bash
set -e

# ==========================
# VARIABLES
# ==========================
WORKDIR="/home/user/workspace"
INVENTORY="${WORKDIR}/inventory.ini"
PLAYBOOK="${WORKDIR}/user-management.yml"

SSH_USER="server1_admin"
SSH_PASS="server1_admin@123!"

# ==========================
# STEP 1: CREATE WORKSPACE
# ==========================
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ==========================
# STEP 2: CREATE INVENTORY
# ==========================
cat > "$INVENTORY" <<EOF
[web]
server1 ansible_host=server1 \
ansible_user=${SSH_USER} \
ansible_password=${SSH_PASS} \
ansible_become=true \
ansible_become_password=${SSH_PASS}
EOF

# ==========================
# STEP 3: CREATE PLAYBOOK
# ==========================
cat > "$PLAYBOOK" <<'EOF'
---
- name: Ansible User Management Complete Workflow
  hosts: web
  become: true
  gather_facts: false

  tasks:
    - name: Ensure dev1 user exists
      user:
        name: dev1
        state: present
        shell: /bin/bash
        create_home: true

    - name: Ensure dev2 user exists
      user:
        name: dev2
        state: present
        shell: /bin/bash
        create_home: true

    - name: Ensure admin user exists
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

# ==========================
# STEP 4: SYNTAX CHECK
# ==========================
ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --syntax-check

# ==========================
# STEP 5: EXECUTE PLAYBOOK
# ==========================
ansible-playbook -i "$INVENTORY" "$PLAYBOOK"

# ==========================
# STEP 6: VERIFICATION
# ==========================

echo "---- USER VERIFICATION ----"
ansible web -i "$INVENTORY" -m command -a "id dev1"
ansible web -i "$INVENTORY" -m command -a "id dev2"
ansible web -i "$INVENTORY" -m command -a "id admin"

echo "---- SHELL VERIFICATION ----"
ansible web -i "$INVENTORY" -m command -a "getent passwd dev1 dev2 admin"

echo "---- HOME DIRECTORY VERIFICATION ----"
ansible web -i "$INVENTORY" -m command -a "ls -ld /home/dev1 /home/dev2 /home/admin"

echo "---- OLDUSER REMOVAL CHECK ----"
if ansible web -i "$INVENTORY" -m command -a "id olduser" &>/dev/null; then
  echo "ERROR: olduser still exists"
  exit 1
else
  echo "olduser successfully removed"
fi

if ansible web -i "$INVENTORY" -m command -a "ls -ld /home/olduser" &>/dev/null; then
  echo "ERROR: /home/olduser still exists"
  exit 1
else
  echo "/home/olduser successfully removed"
fi

# ==========================
# STEP 7: IDEMPOTENCY CHECK
# ==========================
echo "---- IDEMPOTENCY CHECK ----"
ansible-playbook -i "$INVENTORY" "$PLAYBOOK"

echo "LAB COMPLETED SUCCESSFULLY"
