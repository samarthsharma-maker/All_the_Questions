```bash
mkdir -p /home/user/workspace && cd /home/user/workspace

cat > inventory.ini << 'EOF'
[web]
server1 ansible_host=server1 ansible_user=server1_admin ansible_password=server1_admin@123! ansible_become_password=server1_admin@123!
EOF

cat > ../broken-playbook.yml << 'EOF'
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

    - name: Install nginx package
      package:
        name: nginx
        state: present

    - name: Start nginx service
      service:
        name: nginx
        state: started
EOF
```
ansible-playbook -i workspace/inventory.ini broken-playbook.yml --syntax-check
ansible-playbook -i workspace/inventory.ini broken-playbook.yml