#!/usr/bin/env bash
# Run schema initialization before starting any long-lived Django process.
set -euo pipefail
cd /opt/jumpserver

./jms upgrade_db

# A fresh Django process now sees the migrated settings table. Its upstream
# django_ready signal creates TERMINAL_HOST_KEY only if the setting is absent.
# Validate the stored key without resetting it or printing private material.
python apps/manage.py shell <<'PY'
import base64
import hashlib
from cryptography.hazmat.primitives.serialization import (
    Encoding, PublicFormat, load_pem_private_key, load_ssh_private_key,
)
from settings.models import Setting

host_key = Setting.objects.get(name="TERMINAL_HOST_KEY").cleaned_value
if not isinstance(host_key, str) or not host_key.strip():
    raise RuntimeError("TERMINAL_HOST_KEY is empty; refusing to replace an existing setting")
loader = load_ssh_private_key if host_key.startswith("-----BEGIN OPENSSH PRIVATE KEY-----") else load_pem_private_key
private_key = loader(host_key.encode(), password=None)
public_key = private_key.public_key().public_bytes(Encoding.OpenSSH, PublicFormat.OpenSSH)
fingerprint = base64.b64encode(hashlib.sha256(base64.b64decode(public_key.split()[1])).digest()).decode().rstrip("=")
print("Terminal host key ready; public fingerprint SHA256:" + fingerprint)
PY
