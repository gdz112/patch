#!/bin/sh
set -e

echo "[INIT] Fetching Pump secrets from SSM"

export TYK_PMP_ANALYTICSSTORAGECONFIG_PASSWORD="$(python3 /app/fetch_ssm.py /tyk/redis/password)"

if [ -z "${TYK_PMP_ANALYTICSSTORAGECONFIG_PASSWORD}" ]; then
  echo "[FATAL] Redis password missing from SSM /tyk/redis/password"
  exit 1
fi

echo "[INIT] Redis password loaded from SSM"

exec /opt/tyk-pump/tyk-pump
