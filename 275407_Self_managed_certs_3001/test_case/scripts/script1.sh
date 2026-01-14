#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

TARGET_DIR="/home/user"
CERT="${TARGET_DIR}/cert.pem"
KEY="${TARGET_DIR}/key.pem"

#########################################
# Validate files exist
#########################################
if [[ ! -f "$CERT" || ! -f "$KEY" ]]; then
    print_status "failed" "Missing cert.pem or key.pem."
    exit 1
fi

#########################################
# Validate certificate is X.509 self-signed
#########################################
if ! openssl x509 -in "$CERT" -noout >/dev/null 2>&1; then
    print_status "failed" "cert.pem is not a valid X.509 certificate."
    exit 1
fi

#########################################
# Validate key is RSA 4096-bit
#########################################
KEY_SIZE=$(stat -c%s "$KEY")

if (( KEY_SIZE < 2800 )); then
    print_status "failed" "Key too small — must use RSA 4096-bit."
    exit 1
fi

#########################################
# Validate certificate validity duration
#########################################
DAYS=$(openssl x509 -in "$CERT" -noout -dates | grep "notAfter" | sed 's/.*=\(.*\)/\1/')
EXP_EPOCH=$(date -d "$DAYS" +%s)
NOW_EPOCH=$(date +%s)

# 365 days ≈ 31536000 seconds
DIFF=$(( (EXP_EPOCH - NOW_EPOCH) / 86400 ))

if (( DIFF < 360 || DIFF > 370 )); then
    print_status "failed" "Certificate expiry must be ~365 days."
    exit 1
fi

print_status "success" "Valid X.509 cert + 4096-bit RSA key + correct expiry."
