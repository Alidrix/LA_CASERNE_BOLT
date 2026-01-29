#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker Engine is required but not found." >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 is required but not found." >&2
  exit 1
fi

if ! groups "$USER" | grep -q '\bdocker\b'; then
  echo "User '$USER' is not in the docker group. Add it and re-login." >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "OpenSSL is required but not found." >&2
  exit 1
fi

echo "[1/7] Preparing dedicated user/group"
if ! getent group PASSBOLT >/dev/null; then
  sudo groupadd PASSBOLT
fi

if ! id -u thepassbolt >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash -g PASSBOLT thepassbolt
else
  sudo usermod -g PASSBOLT thepassbolt
fi

echo "[2/7] Preparing local folders"
sudo mkdir -p /opt/passbolt/{dc1,dc2}/{gpg_volume,jwt_volume}
sudo mkdir -p /opt/passbolt/dc1/db/data/{galera-1,galera-2}
sudo mkdir -p /opt/passbolt/dc2/db/data/galera-3
sudo chown -R "$USER":"$USER" /opt/passbolt

echo "[3/7] Preparing environment files"
cp -n env/dc1.env.example env/dc1.env
cp -n env/dc2.env.example env/dc2.env

echo "[4/7] Preparing secrets"
mkdir -p secrets
openssl rand -base64 32 > secrets/db_password.txt
openssl rand -base64 32 > secrets/smtp_password.txt
openssl rand -base64 64 > secrets/jwt_secret.txt

echo "[5/7] Starting DC1 stack"
docker compose -f compose/dc1/reverse-proxy.compose.yml \
  -f compose/dc1/passbolt-app.compose.yml \
  -f compose/dc1/db-galera.compose.yml \
  -f compose/dc1/observability.compose.yml up -d

echo "[6/7] Starting DC2 stack"
docker compose -f compose/dc2/reverse-proxy.compose.yml \
  -f compose/dc2/passbolt-app.compose.yml \
  -f compose/dc2/db-galera.compose.yml \
  -f compose/dc2/observability.compose.yml up -d

echo "[7/7] Setting local DNS entries"
sudo tee -a /etc/hosts >/dev/null <<'HOSTS'
127.0.0.1 passbolt-dc1.local
127.0.0.1 passbolt-dc2.local
HOSTS

echo "Setup complete."
