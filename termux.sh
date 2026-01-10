#!/bin/sh

set -e

if ! command -v python >/dev/null 2>&1; then
  echo "Please install python in Termux: pkg install python"
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "Please install openssl in Termux: pkg install openssl-tool"
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CERT_DIR="$SCRIPT_DIR/cert"
DER="$CERT_DIR/pcw_cert.der"
PEM="$CERT_DIR/pcw_cert.pem"

mkdir -p "$CERT_DIR"

if [ ! -f "$PEM" ] && [ -f "$DER" ]; then
  echo "Convirtiendo $DER -> $PEM"
  openssl x509 -inform der -in "$DER" -out "$PEM"
fi

exec python "$SCRIPT_DIR/CIMATOOL.py" "$@"

