#!/usr/bin/env bash
set -euo pipefail

PASSBOLT_USER="thepassbolt"
PASSBOLT_GROUP="passbolt"
BASE_DIR="/opt/passbolt"
SECRETS_DIR="secrets"

#######################################
# Prerequisites
#######################################

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker Engine is required but not found." >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 is required but not found." >&2
  exit 1
fi

if ! id -nG "$USER" | grep -qw docker; then
  echo "User '$USER' is not in the docker group. Add it and re-login." >&2
  exit 1
fi

if ! sudo -n true 2>/dev/null; then
  echo "This script requires sudo privileges." >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "OpenSSL is required but not found." >&2
  exit 1
fi

#######################################
# [1/7] Dedicated user/group
#######################################

echo "[1/7] Preparing dedicated user/group"

if ! getent group "$PASSBOLT_GROUP" >/dev/null; then
  sudo groupadd "$PASSBOLT_GROUP"
fi

if ! id -u "$PASSBOLT_USER" >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash -g "$PASSBOLT_GROUP" "$PASSBOLT_USER"
else
  sudo usermod -g "$PASSBOLT_GROUP" "$PASSBOLT_USER"
fi

#######################################
# [2/7] Local folders
#######################################

echo "[2/7] Preparing local folders"

sudo mkdir -p \
  "$BASE_DIR"/{dc1,dc2}/{gpg_volume,jwt_volume} \
  "$BASE_DIR"/dc1/db/data/{galera-1,galera-2} \
  "$BASE_DIR"/dc2/db/data/galera-3 \
  "$BASE_DIR"/dc1/observability/{prometheus,loki,grafana,oncall-db} \
  "$BASE_DIR"/dc2/observability/{prometheus,loki,grafana,oncall-db}

sudo chown -R "$PASSBOLT_USER":"$PASSBOLT_GROUP" "$BASE_DIR"
sudo chmod -R 750 "$BASE_DIR"

#######################################
# [3/7] Environment files
#######################################

echo "[3/7] Preparing environment files"

sudo -u "$PASSBOLT_USER" cp -n env/dc1.env.example env/dc1.env
sudo -u "$PASSBOLT_USER" cp -n env/dc2.env.example env/dc2.env

#######################################
# [4/7] Secrets
#######################################

echo "[4/7] Preparing secrets"

sudo -u "$PASSBOLT_USER" mkdir -p "$SECRETS_DIR"

sudo -u "$PASSBOLT_USER" bash <<'EOF'
set -euo pipefail
[ -f secrets/db_password.txt ]   || openssl rand -base64 32 > secrets/db_password.txt
[ -f secrets/smtp_password.txt ] || openssl rand -base64 32 > secrets/smtp_password.txt
[ -f secrets/jwt_secret.txt ]    || openssl rand -base64 64 > secrets/jwt_secret.txt
chmod 600 secrets/*.txt
EOF

#######################################
# [5/7] Start DC1 stack
#######################################

echo "[5/7] Starting DC1 stack"

docker compose \
  -f compose/dc1/reverse-proxy.compose.yml \
  -f compose/dc1/passbolt-app.compose.yml \
  -f compose/dc1/db-galera.compose.yml \
  -f compose/dc1/observability.compose.yml \
  up -d

#######################################
# [6/7] Start DC2 stack
#######################################

echo "[6/7] Starting DC2 stack"

docker compose \
  -f compose/dc2/reverse-proxy.compose.yml \
  -f compose/dc2/passbolt-app.compose.yml \
  -f compose/dc2/db-galera.compose.yml \
  -f compose/dc2/observability.compose.yml \
  up -d

#######################################
# [7/7] Local DNS
#######################################

echo "[7/7] Setting local DNS entries"

if ! grep -q "passbolt-dc1.local" /etc/hosts; then
  sudo tee -a /etc/hosts >/dev/null <<'HOSTS'
127.0.0.1 passbolt-dc1.local
127.0.0.1 passbolt-dc2.local
HOSTS
fi

echo "Setup complete."
