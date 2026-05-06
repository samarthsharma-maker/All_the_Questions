#!/bin/bash
# solution.sh — Applies all four fixes to the VaultCore Ansible hardening lab
# by rewriting hardening.yml and ssh_banner.j2 with the correct content.
# Run as: bash solution.sh

set -euo pipefail

BASE_DIR="/home/user/vaultcore-ansible-lab"
PLAYBOOK="${BASE_DIR}/hardening.yml"
TEMPLATE="${BASE_DIR}/templates/ssh_banner.j2"
INVENTORY="${BASE_DIR}/inventory.ini"

echo "============================================================"
echo "  VAULTCORE ANSIBLE LAB — APPLYING FIXES"
echo "============================================================"
echo ""

# --------------------------------------------------
# Preflight checks
# --------------------------------------------------
if [ ! -d "${BASE_DIR}" ]; then
    echo "ERROR: Lab directory ${BASE_DIR} not found. Run the setup script first." >&2
    exit 1
fi

if [ ! -f "${INVENTORY}" ]; then
    echo "ERROR: ${INVENTORY} not found. Run the setup script first." >&2
    exit 1
fi

# --------------------------------------------------
# Ensure inventory.ini has a routable IP for the target node.
# The lab environment always registers the target container
# under the hostname 'server1' in /etc/hosts.
# --------------------------------------------------
function ensure_inventory_has_ip() {
    # If inventory already has a routable IP, leave it alone
    if grep -qE '^\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "${INVENTORY}"; then
        return
    fi

    echo "[0/3] Resolving target node IP from /etc/hosts..."
    local ip
    ip=$(grep -E '\bserver1\b' /etc/hosts | awk '{print $1}' | head -1)

    if [ -z "$ip" ]; then
        echo "ERROR: 'server1' not found in /etc/hosts. Ensure the target container is running." >&2
        exit 1
    fi

    echo "  Target IP: ${ip} — updating inventory.ini..."
    sed -i "s/^target$/${ip}/" "${INVENTORY}"
    echo "  Done."
    echo ""
}

ensure_inventory_has_ip

# --------------------------------------------------
# FIX 1: ansible.builtin.user instead of shell: useradd
# FIX 2: notify string changed to 'restart sshd' (was 'Restart SSH Service')
# FIX 3: become: false removed from the sudoers task
# (All three fixes are in hardening.yml — rewrite it entirely)
# --------------------------------------------------
echo "[1/3] Writing corrected hardening.yml..."

cat > "${PLAYBOOK}" << 'EOF'
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
      ansible.builtin.user:
        name: "{{ deploy_user }}"
        state: present

    - name: Deploy SSH banner
      ansible.builtin.template:
        src: templates/ssh_banner.j2
        dest: /etc/ssh/banner
        owner: root
        group: root
        mode: '0644'
      notify: restart sshd

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

  handlers:
    - name: restart sshd
      ansible.builtin.service:
        name: sshd
        state: restarted
EOF

echo "  Done."
echo ""

# --------------------------------------------------
# FIX 4: app_port -> application_port in template
# --------------------------------------------------
echo "[2/3] Writing corrected ssh_banner.j2..."

cat > "${TEMPLATE}" << 'EOF'
============================================================
  VaultCore Security — Managed Node
  Port: {{ application_port }}
  {{ banner_text }}
============================================================
EOF

echo "  Done."
echo ""

# --------------------------------------------------
# Run 1 — must succeed
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
# Run 2 — idempotency check (must show 0 changed)
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
    echo "ERROR: Playbook is not idempotent — second run reported ${changed_count} changed task(s)." >&2
    exit 1
fi

echo "  Run 2 passed — 0 changes (idempotent)."
echo ""

# --------------------------------------------------
# Summary
# --------------------------------------------------
echo "============================================================"
echo "  ALL FIXES APPLIED AND VERIFIED"
echo "============================================================"
echo ""
echo "  Fix 1 — Create deploy user task"
echo "           shell: useradd -> ansible.builtin.user (state: present)"
echo ""
echo "  Fix 2 — Deploy SSH banner notify string"
echo "           'Restart SSH Service' -> 'restart sshd'"
echo ""
echo "  Fix 3 — Write sudoers entry task"
echo "           removed become: false"
echo ""
echo "  Fix 4 — ssh_banner.j2 template variable"
echo "           {{ app_port }} -> {{ application_port }}"
echo ""
echo "  Playbook ran successfully and is idempotent."
echo "============================================================"