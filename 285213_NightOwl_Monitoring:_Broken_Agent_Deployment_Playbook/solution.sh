#!/bin/bash
# solution.sh — Applies all four fixes to the NightOwl Ansible lab.
# Run as: bash solution.sh

set -euo pipefail

BASE_DIR="/home/user/nightowl-lab"
PLAYBOOK="${BASE_DIR}/deploy_agent.yml"
INVENTORY="${BASE_DIR}/inventory.ini"

echo "============================================================"
echo "  NIGHTOWL ANSIBLE LAB — APPLYING FIXES"
echo "============================================================"
echo ""

if [ ! -d "${BASE_DIR}" ]; then
    echo "ERROR: ${BASE_DIR} not found. Run the setup script first." >&2
    exit 1
fi

# --------------------------------------------------
# Ensure inventory has a routable IP
# --------------------------------------------------
function ensure_inventory_has_ip() {
    if grep -qE '^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "${INVENTORY}"; then
        return
    fi
    echo "[0/3] Resolving target node IP from /etc/hosts..."
    local ip
    ip=$(grep -E '\bserver1\b' /etc/hosts | awk '{print $1}' | head -1)
    if [ -z "$ip" ]; then
        echo "ERROR: 'server1' not found in /etc/hosts." >&2
        exit 1
    fi
    echo "  Target IP: ${ip} — updating inventory.ini..."
    sed -i "s/^target$/${ip}/" "${INVENTORY}"
    echo "  Done."
    echo ""
}

ensure_inventory_has_ip

# --------------------------------------------------
# Write the corrected playbook
#
# Fix 1: removed changed_when: false from "Deploy agent config"
# Fix 2: removed failed_when: false from "Validate agent config"
# Fix 3: changed "{{ item }}" to "{{ pkg_name }}" in apt task
# Fix 4: moved "Stat config directory" above "Check config directory exists"
# --------------------------------------------------
echo "[1/3] Writing corrected deploy_agent.yml..."

cat > "${PLAYBOOK}" << 'EOF'
---
- name: NightOwl Agent Deployment
  hosts: all
  become: true
  vars_files:
    - vars.yml

  tasks:

    - name: Stat config directory
      ansible.builtin.stat:
        path: /etc/nightowl
      register: config_stat

    - name: Check config directory exists
      ansible.builtin.file:
        path: /etc/nightowl
        state: directory
        mode: '0755'
      when: not config_stat.stat.exists

    - name: Install required packages
      ansible.builtin.apt:
        name: "{{ pkg_name }}"
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

    - name: Validate agent config
      ansible.builtin.command:
        cmd: grep -c 'listen_port' /etc/nightowl/agent.conf
      register: validation_result
      changed_when: false

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

echo "  Done."
echo ""

# --------------------------------------------------
# Run 1
# --------------------------------------------------
echo "------------------------------------------------------------"
echo "  RUN 1 — Initial apply"
echo "------------------------------------------------------------"
echo ""

cd "${BASE_DIR}"

first_output=$(ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" 2>&1)
first_exit=$?
echo "${first_output}"
echo ""

if [ "${first_exit}" -ne 0 ]; then
    echo "ERROR: Playbook failed on the first run." >&2
    exit 1
fi
echo "  Run 1 passed."
echo ""

# --------------------------------------------------
# Run 2 — idempotency
# --------------------------------------------------
echo "------------------------------------------------------------"
echo "  RUN 2 — Idempotency check (expect 0 changed)"
echo "------------------------------------------------------------"
echo ""

second_output=$(ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" 2>&1)
second_exit=$?
echo "${second_output}"
echo ""

if [ "${second_exit}" -ne 0 ]; then
    echo "ERROR: Playbook failed on the second run." >&2
    exit 1
fi

changed_count=$(echo "${second_output}" | grep -oP 'changed=\K[0-9]+' | head -1)
changed_count=${changed_count:-0}

if [ "${changed_count}" -gt 0 ]; then
    echo "ERROR: Not idempotent — second run reported ${changed_count} changed task(s)." >&2
    exit 1
fi

echo "  Run 2 passed — 0 changes (idempotent)."
echo ""

echo "============================================================"
echo "  ALL FIXES APPLIED AND VERIFIED"
echo "============================================================"
echo ""
echo "  Fix 1 — Deploy agent config task"
echo "           removed changed_when: false"
echo ""
echo "  Fix 2 — Validate agent config task"
echo "           removed failed_when: false"
echo ""
echo "  Fix 3 — Install required packages task"
echo "           {{ item }} -> {{ pkg_name }}"
echo ""
echo "  Fix 4 — Task order"
echo "           Stat task moved above the when: condition that references it"
echo ""
echo "  Playbook ran successfully and is idempotent."
echo "============================================================"