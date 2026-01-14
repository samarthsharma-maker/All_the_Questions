#!/usr/bin/env bash

set -euo pipefail

WORKDIR="/home/user/workspace"
INVENTORY="$WORKDIR/inventory.ini"
PLAYBOOK="$WORKDIR/file-operations.yml"

echo "=== Setting up workspace ==="
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "=== Creating inventory.ini ==="
cat > "$INVENTORY" << 'EOF'
[web]
server1 ansible_host=server1 ansible_user=server1_admin ansible_password=server1_admin@123! ansible_become_password=server1_admin@123!
EOF

echo "=== Creating temporary file on server1 ==="
ansible web -i "$INVENTORY" -m shell -a "touch /tmp/old_file.txt"

echo "=== Creating file-operations.yml playbook ==="
cat > "$PLAYBOOK" << 'EOF'
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

    - name: Create configuration file
      file:
        path: /opt/app/config/app.conf
        state: file
        owner: root
        group: root
        mode: '0644'


    - name: Remove temporary file
      file:
        path: /tmp/old_file.txt
        state: absent
EOF

echo "=== Running syntax check ==="
ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --syntax-check

echo "=== Executing playbook ==="
ansible-playbook -i "$INVENTORY" "$PLAYBOOK"

echo "=== Solution completed successfully ==="
exit 0