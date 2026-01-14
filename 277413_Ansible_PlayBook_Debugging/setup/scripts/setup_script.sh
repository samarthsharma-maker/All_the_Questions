#!/bin/bash

set -euo pipefail

TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/broken-playbook.yml"

echo "Creating broken Ansible playbook at ${TARGET_FILE} ..."

function create_broken_playbook() {
    cat <<EOF > "${TARGET_FILE}"
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
	
	- name: Install nginx package
	package:
	name: nginx
	state: present
	
	- name: Start nginx service
	service:
	name: nginx
	state started
EOF
    echo "Broken Ansible playbook created at ${TARGET_FILE}"

chown user:user "${TARGET_FILE}" 2>/dev/null || true
}

create_broken_playbook