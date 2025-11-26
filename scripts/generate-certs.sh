#!/bin/bash
# Generate self-signed certificates for local development
# Usage: ./scripts/generate-certs.sh [domain]

DOMAIN=${1:-localhost}
CERTS_DIR="certs/${DOMAIN}"

mkdir -p "$CERTS_DIR"

# MSYS_NO_PATHCONV prevents Git Bash from converting /CN= to a Windows path
MSYS_NO_PATHCONV=1 openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$CERTS_DIR/privkey.pem" \
  -out "$CERTS_DIR/fullchain.pem" \
  -subj "/CN=${DOMAIN}" \
  -addext "subjectAltName=DNS:${DOMAIN},DNS:*.${DOMAIN}"

echo "✅ Certificates generated in $CERTS_DIR"
echo "   - $CERTS_DIR/fullchain.pem"
echo "   - $CERTS_DIR/privkey.pem"
