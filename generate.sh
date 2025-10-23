#!/bin/bash
set -e

NAME="$1"
[ -z "$NAME" ] && { echo "Usage: $0 <name>"; exit 1; }

# Path setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"
OUTPUT_DIR="${SCRIPT_DIR}/certs/ovpn_output"

mkdir -p "$OUTPUT_DIR"

# Step 1: Generate private key
openssl genrsa -out "${OUTPUT_DIR}/${NAME}Key.pem" 2048

# Step 2: Generate CSR
openssl req -new -key "${OUTPUT_DIR}/${NAME}Key.pem" \
  -out "${OUTPUT_DIR}/${NAME}Req.pem" -subj "/CN=${NAME}"

# Step 3: Sign cert
openssl x509 -req -in "${OUTPUT_DIR}/${NAME}Req.pem" \
  -CA "${CERTS_DIR}/rootCA.crt" -CAkey "${CERTS_DIR}/rootCA.key" -CAcreateserial \
  -out "${OUTPUT_DIR}/${NAME}Cert.pem" -days 1825 \
  -extfile <(echo -e "subjectAltName=DNS:${NAME}\nextendedKeyUsage=clientAuth")

# Step 4: Insert cert and key into template
awk -v cert_file="${OUTPUT_DIR}/${NAME}Cert.pem" \
    -v key_file="${OUTPUT_DIR}/${NAME}Key.pem" '
/<cert>/ {
  print;
  while (getline && $0 !~ /<\/cert>/) {};
  while ((getline line < cert_file) > 0) print line;
  print "</cert>";
  next
}
/<key>/ {
  print;
  while (getline && $0 !~ /<\/key>/) {};
  while ((getline line < key_file) > 0) print line;
  print "</key>";
  next
}
{ print }
' "${CERTS_DIR}/vpnconfig.ovpn" > "${OUTPUT_DIR}/${NAME}.ovpn"

echo "✅ Created ${OUTPUT_DIR}/${NAME}.ovpn"

# Cleanup intermediate files
rm -f "${OUTPUT_DIR}/${NAME}Key.pem" "${OUTPUT_DIR}/${NAME}Req.pem" "${OUTPUT_DIR}/${NAME}Cert.pem"
