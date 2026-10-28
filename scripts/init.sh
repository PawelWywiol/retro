#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  cp .env.example .env
  chmod 600 .env
  created=1
  echo "created .env"
fi

for key in DB_PASSWD DB_ROOT_PASSWD ROMM_AUTH_SECRET_KEY; do
  if grep -qx "${key}=" .env; then
    sed -i "s|^${key}=$|${key}=$(openssl rand -hex 32)|" .env
    echo "generated ${key}"
  fi
done

if [[ "${created:-}" == 1 ]]; then
  echo "set LIBRARY_PATH and DATA_PATH in .env, then run make init again"
  exit 0
fi

set -a
# shellcheck source=/dev/null
. ./.env
set +a

mkdir -p \
  "${LIBRARY_PATH}/roms" \
  "${LIBRARY_PATH}/bios" \
  "${DATA_PATH}/romm/resources" \
  "${DATA_PATH}/romm/assets" \
  "${DATA_PATH}/romm/config" \
  "${DATA_PATH}/romm/redis" \
  "${DATA_PATH}/mariadb" \
  "${DATA_PATH}/gluetun" \
  "${DATA_PATH}/minerva"

if [[ ! -f "${DATA_PATH}/romm/config/config.yml" ]]; then
  cp config/romm/config.yml "${DATA_PATH}/romm/config/config.yml"
  echo "copied romm config.yml"
fi

echo "done, review .env then run: make up"
