#!/bin/bash

set -euo pipefail

TARGET_DIR="/home/user"
PY_FILE="${TARGET_DIR}/app.py"

echo "Setting up misconfigured Python HTTPS app..."

mkdir -p "${TARGET_DIR}"

cat <<EOF > "${PY_FILE}"
import os
from flask import Flask, request

app = Flask(__name__)

@app.route("/")
def hello():
    return "Hello! I am running on " + ("HTTPS" if request.is_secure else "HTTP")

if __name__ == "__main__":
    cert_file = 'cert.pem'
    key_file = 'key.pem'

    if os.path.exists(cert_file) and os.path.exists(key_file):
        print("Certificates found. Starting in HTTPS mode...")
        ssl_context = (cert_file, key_file)
    else:
        print("No certificates found. Starting in HTTP mode...")
        ssl_context = None

    app.run(port=3001, ssl_context=ssl_context)
EOF

# Ensure NO certs exist (forcing failure state)
rm -f "${TARGET_DIR}/cert.pem" "${TARGET_DIR}/key.pem" 2>/dev/null || true

chown -R user:user "${TARGET_DIR}" 2>/dev/null || true
apt update -y
apt install python3-flask

echo "Setup complete. HTTPS will NOT work until a self-signed cert is created."
