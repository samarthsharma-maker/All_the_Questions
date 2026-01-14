#!/bin/bash

set -euo pipefail
TARGET_DIR="/home/user"
TARGET_FILE="${TARGET_DIR}/server.log"

# Enter the Content Here
# func function_name() {
#     :
# }
function create_file() {
    cat > "${TARGET_FILE}" <<'EOF'
2026-01-12:185.220.101.33:10:01:01:GET:/index.php:HTTP/1.1:200:1024:Mozilla/5.0
2026-01-12:45.33.21.156:10:01:02:GET:/images/logo.png:HTTP/1.1:200:2048:Chrome/108.0
2026-01-12:98.76.54.32:10:01:03:POST:/api/auth:HTTP/1.1:401:128:curl/7.81.0
2026-01-12:192.168.1.100:10:01:04:GET:/dashboard:HTTP/1.1:200:4096:Chrome/108.0
2026-01-12:185.220.101.33:10:01:05:POST:/wp-login.php:HTTP/1.1:403:0:Python-urllib/3.9
2026-01-12:203.0.113.200:10:01:06:OPTIONS:/api/v1/status:HTTP/1.1:200:0:kubectl/1.25
2026-01-12:45.33.21.156:10:01:07:POST:/admin/login:HTTP/1.1:403:0:curl/7.68.0
2026-01-12:98.76.54.32:10:01:08:GET:/profile:HTTP/1.1:200:512:Mozilla/5.0
2026-01-12:185.220.101.33:10:01:09:POST:/wp-login.php:HTTP/1.1:401:0:curl/7.68.0
2026-01-12:123.45.67.89:10:01:10:GET:/health:HTTP/1.1:200:64:Prometheus/2.45
2026-01-12:45.33.21.156:10:01:11:POST:/admin/login:HTTP/1.1:401:0:curl/7.68.0
2026-01-12:98.76.54.32:10:01:12:POST:/api/auth:HTTP/1.1:403:256:curl/7.81.0
2026-01-12:192.168.1.100:10:01:13:GET:/metrics:HTTP/1.1:200:1024:Prometheus/2.45
2026-01-12:185.220.101.33:10:01:14:GET:/robots.txt:HTTP/1.1:200:128:curl/7.68.0
2026-01-12:45.33.21.156:10:01:15:POST:/admin/login:HTTP/1.1:403:0:Mozilla/5.0
2026-01-12:203.0.113.200:10:01:16:GET:/status:HTTP/1.1:200:256:kubectl/1.25
2026-01-12:98.76.54.32:10:01:17:POST:/api/auth:HTTP/1.1:401:128:curl/7.81.0
EOF
}

create_file

echo "Creating/updating ${TARGET_FILE} ..."
chown user:user "${TARGET_FILE}" 2>/dev/null || true
