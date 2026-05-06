#!/bin/bash
# setup-nightowl-lab.sh
# Sets up the NightOwl agent deployment lab on the control node
# and prepares the target node via Ansible.
# Run as: bash setup-nightowl-lab.sh

set -euo pipefail

HOME_DIR="/home/user"
BASE_DIR="/home/user/nightowl-lab"
TEMPLATES_DIR="${BASE_DIR}/templates"

mkdir -p "${TEMPLATES_DIR}"

function log() { echo "[setup] $*"; }

# --------------------------------------------------
# Discover target node IP from /etc/hosts
# --------------------------------------------------
function discover_target_ip() {
    local ip
    ip=$(grep -E '\bserver1\b' /etc/hosts | awk '{print $1}' | head -1)
    if [ -z "$ip" ]; then
        echo "server1" 
    else
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
# --------------------------------------------------
function write_vars() {
    log "Writing vars.yml..."
    cat > "${BASE_DIR}/vars.yml" <<'EOF'
---
nightowl_listen_port: 9110
nightowl_log_level: "info"
nightowl_scrape_interval: 30
required_packages:
  - curl
  - python3-pip
EOF
    log "  vars.yml written"
}

# --------------------------------------------------
# Jinja2 template (correct — bugs are in the playbook only)
# --------------------------------------------------
function write_template() {
    log "Writing agent.conf.j2..."
    cat > "${TEMPLATES_DIR}/agent.conf.j2" <<'EOF'
# NightOwl Agent Configuration
# Managed by Ansible — do not edit manually

listen_port = {{ nightowl_listen_port }}
log_level   = {{ nightowl_log_level }}
scrape_interval = {{ nightowl_scrape_interval }}
EOF
    log "  templates/agent.conf.j2 written"
}

# --------------------------------------------------
# Broken playbook
#
# BUG 1 — changed_when: false on "Deploy agent config"
#   Ansible notifies handlers only when a task result is 'changed'.
#   changed_when: false forces the result to always be 'ok' regardless
#   of whether the template actually changed the file. The handler is
#   never triggered and the agent service never restarts after a config
#   change, even though the playbook reports no errors.
#   Fix: remove changed_when: false
#
# BUG 2 — failed_when: false on "Validate agent config"
#   failed_when: false tells Ansible to never fail this task regardless
#   of the command's exit code. The validation step becomes a no-op —
#   it always passes silently even if the config file is malformed or
#   the check tool reports an error.
#   Fix: remove failed_when: false (let the command's rc speak for itself)
#
# BUG 3 — loop_var: pkg_name but task uses {{ item }}
#   loop_control.loop_var overrides the default loop variable name from
#   'item' to 'pkg_name'. Inside the loop, {{ item }} is no longer
#   defined — Ansible raises AnsibleUndefinedVariable on the first
#   iteration. The task must reference {{ pkg_name }} instead.
#   Fix: change "{{ item }}" to "{{ pkg_name }}"
#
# BUG 4 — Task order: "Check config dir" uses config_stat before
#          "Stat config dir" runs and registers it.
#   config_stat is registered by the stat task, but the task that
#   references config_stat.stat.exists appears BEFORE the stat task
#   in the play. Ansible raises a conditional check failure on the
#   first run: 'config_stat' is undefined.
#   Fix: move the stat task above the task that references config_stat
# --------------------------------------------------
function write_playbook() {
    log "Writing deploy_agent.yml (4 bugs planted)..."
    cat > "${BASE_DIR}/deploy_agent.yml" <<'EOF'
---
- name: NightOwl Agent Deployment
  hosts: all
  become: true
  vars_files:
    - vars.yml

  tasks:

    - name: Check config directory exists
      ansible.builtin.file:
        path: /etc/nightowl
        state: directory
        mode: '0755'
      when: not config_stat.stat.exists

    - name: Stat config directory
      ansible.builtin.stat:
        path: /etc/nightowl
      register: config_stat

    - name: Install required packages
      ansible.builtin.apt:
        name: "{{ item }}"
        state: present
        update_cache: true
      loop: "{{ required_packages }}"
      loop_control:
        loop_var: pkg_name

    - name: Deploy agent config
      ansible.builtin.template:
        src: templates/agent.conf.j2
        dest: /etc/nightowl/agent.conf
        owner: root
        group: root
        mode: '0644'
      notify: restart nightowl-agent
      changed_when: false

    - name: Validate agent config
      ansible.builtin.command:
        cmd: grep -c 'listen_port' /etc/nightowl/agent.conf
      register: validation_result
      changed_when: false
      failed_when: false

    - name: Ensure nightowl-agent service is running
      ansible.builtin.systemd:
        name: nightowl-agent
        state: started
        enabled: true

  handlers:
    - name: restart nightowl-agent
      ansible.builtin.systemd:
        name: nightowl-agent
        state: restarted
EOF
    log "  deploy_agent.yml written"
}

# --------------------------------------------------
# Prepare the target node via Ansible ad-hoc commands:
#   - Create /etc/nightowl directory
#   - Write stub agent.conf
#   - Install nightowl-agent systemd unit
#   - Start the service
# Using ansible instead of raw SSH so become/sudo is handled correctly.
# --------------------------------------------------
function prepare_target() {
    log "Preparing target node..."

    TARGET_IP=$(discover_target_ip)

    # Write a temporary prep playbook and run it
    local prep_playbook
    prep_playbook=$(mktemp /tmp/nightowl-prep-XXXX.yml)

    cat > "${prep_playbook}" << 'EOF'
---
- name: Prepare NightOwl target node
  hosts: all
  become: true

  tasks:

    - name: Create /etc/nightowl directory
      ansible.builtin.file:
        path: /etc/nightowl
        state: directory
        mode: '0755'

    - name: Write stub agent.conf
      ansible.builtin.copy:
        dest: /etc/nightowl/agent.conf
        mode: '0644'
        content: |
          # NightOwl Agent Configuration
          listen_port = 9110
          log_level   = info
          scrape_interval = 30

    - name: Install nightowl-agent systemd unit
      ansible.builtin.copy:
        dest: /etc/systemd/system/nightowl-agent.service
        mode: '0644'
        content: |
          [Unit]
          Description=NightOwl Monitoring Agent
          After=network.target

          [Service]
          ExecStart=/bin/sleep infinity
          Restart=always
          RestartSec=5

          [Install]
          WantedBy=multi-user.target

    - name: Reload systemd daemon
      ansible.builtin.systemd:
        daemon_reload: true

    - name: Enable and start nightowl-agent
      ansible.builtin.systemd:
        name: nightowl-agent
        state: started
        enabled: true
EOF

    ansible-playbook -i "${BASE_DIR}/inventory.ini" "${prep_playbook}" \
        2>&1 | sed 's/^/  /'
    prep_exit="${PIPESTATUS[0]}"

    rm -f "${prep_playbook}"

    if [ "${prep_exit}" -ne 0 ]; then
        log "  ERROR: Target node preparation failed (exit ${prep_exit})." >&2
        exit 1
    fi
    log "  Target node ready"
}

# --------------------------------------------------
# imp_info.txt
# --------------------------------------------------
function create_imp_info_file() {
    cat > "${HOME_DIR}/imp_info.txt" <<EOF

============================================================
  NIGHTOWL MONITORING — ANSIBLE DEPLOYMENT LAB
============================================================

  Lab directory:  ${BASE_DIR}/
  Playbook:       ${BASE_DIR}/deploy_agent.yml
  Inventory:      ${BASE_DIR}/inventory.ini
  Variables:      ${BASE_DIR}/vars.yml
  Template:       ${BASE_DIR}/templates/agent.conf.j2

  Target node:
    User:      server1_admin
    Password:  server1_admin@123!

  Run the playbook:
    cd ${BASE_DIR}
    ansible-playbook -i inventory.ini deploy_agent.yml

  A second run must produce zero changes.

============================================================
EOF
    log "  imp_info.txt written"
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "Setting up NightOwl Ansible Lab..."
    echo ""

    echo "[1/6] Writing inventory..."
    write_inventory

    echo "[2/6] Writing vars.yml..."
    write_vars

    echo "[3/6] Writing agent.conf.j2..."
    write_template

    echo "[4/6] Writing deploy_agent.yml (broken)..."
    write_playbook

    echo "[5/6] Preparing target node..."
    prepare_target

    echo "[6/6] Writing imp_info.txt..."
    create_imp_info_file

    echo ""
    echo "============================================================"
    echo "  NIGHTOWL ANSIBLE LAB — READY"
    echo "============================================================"
    echo ""
    echo "  Lab files:  ${BASE_DIR}/"
    echo "  4 bugs planted in deploy_agent.yml"
    echo ""
    echo "  Run: cat ${HOME_DIR}/imp_info.txt"
    echo "============================================================"
}

main

chown -R user:user "${BASE_DIR}" 2>/dev/null || true