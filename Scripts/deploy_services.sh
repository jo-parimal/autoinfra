#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <EC2_IP> <PATH_TO_PRIVATE_KEY_PEM> [DB_HOST]"
  exit 2
fi

EC2_IP="$1"
SSH_KEY="$2" 
DB_HOST="${3:-}"   # optional third arg

EC2_USER="deployer"   # we installed public key for this user
SERVICES_DIR="services"

if [ ! -d "${SERVICES_DIR}" ]; then
  echo "services/ directory not found"
  exit 3
fi

index=0
for svc in $(ls -1 ${SERVICES_DIR}); do
  index=$((index + 1))
  PORT=$((8080 + index))
  REMOTE_DIR="/opt/services/${svc}"
  echo "Deploying ${svc} -> ${EC2_IP}:${REMOTE_DIR} (port ${PORT})"

  # determine local jar
  JAR_LOCAL=""
  if ls ${SERVICES_DIR}/${svc}/target/*.jar 1> /dev/null 2>&1; then
    JAR_LOCAL=$(ls ${SERVICES_DIR}/${svc}/target/*.jar | head -1)
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
ExecStart=/usr/bin/java -jar %REMOTE_DIR%/%JAR_NAME% --server.port=%PORT% %DB_ARG%
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
DB_ARG=""
if [ -n "${DB_HOST}" ]; then
  DB_ARG="--spring.datasource.url=jdbc:postgresql://${DB_HOST}:5432/autoinfra --spring.datasource.username=admin --spring.datasource.password=${DB_PASSWORD:-admin}"
fi

# substitute and run remote
REMOTE_CMD=$(echo "${SSH_CMD}" | sed -e "s|%REMOTE_DIR%|${REMOTE_DIR}|g" -e "s|%SVC%|${svc}|g" -e "s|%JAR_NAME%|${JAR_BASENAME}|g" -e "s|%PORT%|${PORT}|g" -e "s|%DB_ARG%|${DB_ARG}|g")
ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_IP} "${REMOTE_CMD}"

done

echo "All services deployed."
