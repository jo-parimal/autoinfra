#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <EC2_IP> <PATH_TO_PRIVATE_KEY_PEM> [DB_HOST]"
  exit 2
fi
#just a cmnt
EC2_IP="$1"
SSH_KEY="$2" 
DB_HOST="${3:-}"   # optional third arg
DB_USER="${DB_USER:-infraadmin}"
DB_PASSWORD="${DB_PASSWORD:-}"

EC2_USER="deployer"   # we installed public key for this user
SERVICES_DIR="services"

if [ ! -d "${SERVICES_DIR}" ]; then
  echo "services/ directory not found"
  exit 3
fi

SERVICES=("user-service:8081" "product-service:8082" "order-service:8083")

for item in "${SERVICES[@]}"; do
  IFS=":" read -r svc PORT <<<"${item}"
  REMOTE_DIR="/opt/services/${svc}"
  echo "Deploying ${svc} -> ${EC2_IP}:${REMOTE_DIR} (port ${PORT})"

  # determine local jar
  JAR_LOCAL=""
  shopt -s nullglob
  jar_candidates=("${SERVICES_DIR}/${svc}/target/"*.jar)
  shopt -u nullglob
  if [ ${#jar_candidates[@]} -gt 0 ]; then
    JAR_LOCAL="${jar_candidates[0]}"
  elif [ -f "${SERVICES_DIR}/${svc}/app.jar" ]; then
    JAR_LOCAL="${SERVICES_DIR}/${svc}/app.jar"
  else
    echo "No jar found for ${svc}, skipping"
    continue
  fi

  scp -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${JAR_LOCAL}" ${EC2_USER}@${EC2_IP}:/tmp/${svc}.jar

  # render systemd unit remotely and start service
  SSH_CMD=$(cat <<'SSH_COMMAND'
sudo mkdir -p %REMOTE_DIR%
sudo mv /tmp/%SVC%.jar %REMOTE_DIR%/
sudo chown -R deployer:deployer %REMOTE_DIR%
cat > /tmp/%SVC%.service <<UNIT
[Unit]
Description=AutoInfra %SVC% service
After=network.target

[Service]
User=deployer
WorkingDirectory=%REMOTE_DIR%
EnvironmentFile=%REMOTE_DIR%/.env
ExecStart=/usr/bin/java -jar %REMOTE_DIR%/%JAR_NAME% --server.port=%PORT%
SuccessExitStatus=143
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
sudo mv /tmp/%SVC%.service /etc/systemd/system/%SVC%.service
sudo systemctl daemon-reload
sudo systemctl enable %SVC%.service
sudo systemctl restart %SVC%.service
SSH_COMMAND
)

# prepare values
JAR_BASENAME=$(basename "${JAR_LOCAL}")
ENV_FILE_CONTENT=""
if [ -n "${DB_HOST}" ]; then
  DB_HOSTNAME="${DB_HOST%%:*}"
  DB_PORT="${DB_HOST##*:}"
  if [ "${DB_PORT}" = "${DB_HOST}" ]; then
    DB_PORT="5432"
  fi
  DB_ARG="--spring.datasource.url=jdbc:postgresql://${DB_HOSTNAME}:${DB_PORT}/autoinfra --spring.datasource.username=${DB_USER} --spring.datasource.password=${DB_PASSWORD}"
fi

# substitute and run remote
REMOTE_CMD=$(echo "${SSH_CMD}" | sed -e "s|%REMOTE_DIR%|${REMOTE_DIR}|g" -e "s|%SVC%|${svc}|g" -e "s|%JAR_NAME%|${JAR_BASENAME}|g" -e "s|%PORT%|${PORT}|g")
ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_IP} "${REMOTE_CMD}"
if [ -n "${ENV_FILE_CONTENT}" ]; then
  printf '%s\n' "${ENV_FILE_CONTENT}" | ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_IP} "cat > /tmp/${svc}.env && sudo mv /tmp/${svc}.env ${REMOTE_DIR}/.env && sudo chown deployer:deployer ${REMOTE_DIR}/.env && sudo chmod 600 ${REMOTE_DIR}/.env && sudo systemctl restart ${svc}.service"
else
  ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_IP} "touch ${REMOTE_DIR}/.env && sudo chown deployer:deployer ${REMOTE_DIR}/.env && sudo chmod 600 ${REMOTE_DIR}/.env"
fi

done

echo "All services deployed."
