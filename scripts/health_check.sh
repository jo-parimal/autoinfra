#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <EC2_IP> <PATH_TO_PRIVATE_KEY_PEM> [DB_HOST_OR_ENDPOINT]"
  exit 2
fi

EC2_IP="$1"
SSH_KEY="$2"
DB_ENDPOINT="${3:-}"
EC2_USER="deployer"

SERVICES=("user-service:8081:/users" "product-service:8082:/products" "order-service:8083:/orders")

echo "==> Checking SSH access to ${EC2_USER}@${EC2_IP}"
ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${EC2_USER}@${EC2_IP}" "echo 'SSH OK'"

if [ -n "${DB_ENDPOINT}" ]; then
  DB_HOST="${DB_ENDPOINT%%:*}"
  DB_PORT="${DB_ENDPOINT##*:}"
  if [ "${DB_PORT}" = "${DB_ENDPOINT}" ]; then
    DB_PORT="5432"
  fi
  echo "==> Checking DB reachability from EC2 (${DB_HOST}:${DB_PORT})"
  ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${EC2_USER}@${EC2_IP}" \
    "timeout 8 bash -lc '</dev/tcp/${DB_HOST}/${DB_PORT}' && echo 'DB TCP reachable' || (echo 'DB TCP unreachable' && exit 1)"
fi

echo "==> Checking systemd status and open ports on EC2"
for spec in "${SERVICES[@]}"; do
  IFS=":" read -r svc port _path <<<"${spec}"
  ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${EC2_USER}@${EC2_IP}" \
    "sudo systemctl is-active --quiet ${svc}.service && echo '${svc} systemd active' || (sudo systemctl status ${svc}.service --no-pager; exit 1)"
  ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${EC2_USER}@${EC2_IP}" \
    "ss -lnt '( sport = :${port} )' | grep -q LISTEN && echo '${svc} listening on ${port}' || (echo '${svc} not listening on ${port}' && exit 1)"
done

echo "==> Checking HTTP responses from deployed services"
for spec in "${SERVICES[@]}"; do
  IFS=":" read -r svc port path <<<"${spec}"
  url="http://${EC2_IP}:${port}${path}"
  code=$(curl -sS -o /tmp/${svc}_health.out -w "%{http_code}" --max-time 10 "${url}" || true)
  if [ "${code}" != "200" ]; then
    echo "${svc} health check failed (${url}) status=${code}"
    cat "/tmp/${svc}_health.out" || true
    exit 1
  fi
  echo "${svc} HTTP OK (${url})"
done

echo "✅ All infra/service health checks passed."
