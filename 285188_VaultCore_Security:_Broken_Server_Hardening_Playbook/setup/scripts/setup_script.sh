#!/bin/bash
# setup-ansible-lab.sh
# Writes the broken VaultCore hardening playbook and supporting files.
# Run as: bash setup-ansible-lab.sh
#
# Environment:
#   Control node: user / user@123!   (this machine)
#   Target node:  server1_admin / server1_admin@123!  (hostname: target)
#   ansible.cfg:  host_key_checking = False (pre-configured)

set -euo pipefail

HOME_DIR="/home/user"
BASE_DIR="/home/user/vaultcore-ansible-lab"
TEMPLATES_DIR="${BASE_DIR}/templates"

mkdir -p "${TEMPLATES_DIR}"

function log() { echo "[setup] $*"; }

# --------------------------------------------------
# Discover target node IP from /etc/hosts
# The lab environment always registers the target container
# under the hostname 'server1' in /etc/hosts.
# --------------------------------------------------
function discover_target_ip() {
    local ip
    ip=$(grep -E '\bserver1\b' /etc/hosts | awk '{print $1}' | head -1)
    if [ -z "$ip" ]; then
        log "  WARNING: 'server1' not found in /etc/hosts. Falling back to hostname 'server1'." >&2
        echo "server1"
    else
        log "  Target node IP: ${ip}" >&2
        echo "$ip"
    fi
}

# --------------------------------------------------
# Inventory
# --------------------------------------------------
function write_inventory() {
    log "Writing inventory.ini..."

    TARGET_IP=$(discover_target_ip)

    cat > "${BASE_DIR}/inventory.ini" <<EOF
[servers]
${TARGET_IP}

[servers:vars]
ansible_user=server1_admin
ansible_password=server1_admin@123!
ansible_become_password=server1_admin@123!
EOF
    log "  inventory.ini written (target: ${TARGET_IP})"
}

# --------------------------------------------------
# vars.yml
# Variable 'application_port' is intentionally defined here.
# The template references 'app_port' (wrong name) — that is BUG 4.
# --------------------------------------------------
function write_vars() {
    log "Writing vars.yml..."
    cat > "${BASE_DIR}/vars.yml" <<'EOF'
---
application_port: 8443
banner_text: "Authorized access only. All activity is monitored."
EOF
    log "  vars.yml written"
}

# --------------------------------------------------
# Jinja2 template (BROKEN)
#
# BUG 4 — Template references {{ app_port }} but vars.yml
#   defines the variable as 'application_port'. Ansible raises
#   AnsibleUndefinedVariable at render time — the task fails on
#   every run with "app_port is undefined".
#
#   Broken:   {{ app_port }}
#   Correct:  {{ application_port }}
# --------------------------------------------------
function write_template() {
    log "Writing ssh_banner.j2 (broken variable name)..."
    cat > "${TEMPLATES_DIR}/ssh_banner.j2" <<'EOF'
============================================================
  VaultCore Security — Managed Node
  Port: {{ app_port }}
  {{ banner_text }}
============================================================
EOF
    # {{ app_port }} is intentionally wrong. Correct: {{ application_port }}
    log "  templates/ssh_banner.j2 written"
}

# --------------------------------------------------
# Broken playbook
#
# BUG 1 — 'Create deploy user' uses shell: useradd
#   Not idempotent. Exits with code 9 on re-run because the
#   user already exists, failing the entire play.
#   Correct: ansible.builtin.user module with state: present
#
# BUG 2 — 'Deploy SSH banner' notifies 'Restart SSH Service'
#   but the handler is named 'restart sshd'. Ansible matches
#   notify strings case-sensitively — the handler is never
#   triggered and sshd is never restarted after banner changes.
#   Correct: change notify to 'restart sshd' (or rename handler)
#
# BUG 3 — 'Write sudoers entry' has become: false
#   Overrides the play-level become: true. Writing to
#   /etc/sudoers.d/ requires root — this task fails immediately
#   with permission denied.
#   Correct: remove become: false
#
# BUG 4 — ssh_banner.j2 references {{ app_port }} (see template above)
# --------------------------------------------------
function write_playbook() {
    log "Writing hardening.yml (4 bugs planted)..."
    cat > "${BASE_DIR}/hardening.yml" <<'EOF'
---
- name: VaultCore Server Hardening
  hosts: all
  become: true
  vars_files:
    - vars.yml

  vars:
    deploy_user: deploy_user
    sudoers_file: /etc/sudoers.d/deploy_user

  tasks:

    - name: Create deploy user
      shell: useradd {{ deploy_user }}

    - name: Deploy SSH banner
      ansible.builtin.template:
        src: templates/ssh_banner.j2
        dest: /etc/ssh/banner
        owner: root
        group: root
        mode: '0644'
      notify: Restart SSH Service

    - name: Configure sshd to use banner
      ansible.builtin.lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?Banner'
        line: 'Banner /etc/ssh/banner'
        state: present
      notify: restart sshd

    - name: Write sudoers entry
      ansible.builtin.copy:
        content: "{{ deploy_user }} ALL=(ALL) NOPASSWD: /usr/bin/systemctl\n"
        dest: "{{ sudoers_file }}"
        owner: root
        group: root
        mode: '0440'
      become: false

  handlers:
    - name: restart sshd
      ansible.builtin.service:
        name: sshd
        state: restarted
EOF
    log "  hardening.yml written"
}

# --------------------------------------------------
# Important info file
# --------------------------------------------------
function create_imp_info_file() {
    cat > "${HOME_DIR}/imp_info.txt" <<EOF

============================================================
  VAULTCORE SECURITY — ANSIBLE HARDENING LAB
============================================================

  Lab directory:  ${BASE_DIR}/
  Playbook:       ${BASE_DIR}/hardening.yml
  Inventory:      ${BASE_DIR}/inventory.ini
  Variables:      ${BASE_DIR}/vars.yml
  Template:       ${BASE_DIR}/templates/ssh_banner.j2

  Target node:
    Hostname:  target
    User:      server1_admin
    Password:  server1_admin@123!

  There are 4 bugs across hardening.yml and ssh_banner.j2.
  Find and fix them all, then run the playbook twice —
  the second run must produce zero changes.

  ── USEFUL COMMANDS ─────────────────────────────────────

  # Syntax check (catches YAML/template errors)
  cd ${BASE_DIR}
  ansible-playbook -i inventory.ini hardening.yml --syntax-check

  # Dry run
  ansible-playbook -i inventory.ini hardening.yml --check

  # Run playbook
  ansible-playbook -i inventory.ini hardening.yml

  # Verify target state after fix
  ansible all -i inventory.ini -m shell -a "id deploy_user"
  ansible all -i inventory.ini -m shell -a "cat /etc/ssh/banner"
  ansible all -i inventory.ini -m shell -a "grep Banner /etc/ssh/sshd_config"
  ansible all -i inventory.ini -m shell -a "cat /etc/sudoers.d/deploy_user"

============================================================
EOF
    log "  imp_info.txt written to ${HOME_DIR}"
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "Setting up VaultCore Ansible Lab..."
    echo ""

    echo "[1/5] Writing inventory..."
    write_inventory

    echo "[2/5] Writing vars.yml..."
    write_vars

    echo "[3/5] Writing ssh_banner.j2 (broken)..."
    write_template

    echo "[4/5] Writing hardening.yml (broken)..."
    write_playbook

    echo "[5/5] Writing important info file..."
    create_imp_info_file

    echo ""
    echo "============================================================"
    echo "  VAULTCORE ANSIBLE LAB — READY"
    echo "============================================================"
    echo ""
    echo "  Lab files:  ${BASE_DIR}/"
    echo "  4 bugs planted across hardening.yml and ssh_banner.j2"
    echo ""
    echo "  Run: cat ${HOME_DIR}/imp_info.txt"
    echo "============================================================"
}

main

chown -R user:user "${BASE_DIR}" 2>/dev/null || true