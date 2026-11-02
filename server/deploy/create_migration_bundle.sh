#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/daka/server}"
OUT_DIR="${OUT_DIR:-/root/daka-migration}"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="${OUT_DIR}/${STAMP}"
ENV_FILE="${APP_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}"
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

mkdir -p "${WORK_DIR}"
chmod 700 "${OUT_DIR}" "${WORK_DIR}"

MYSQL_CNF="$(mktemp)"
chmod 600 "${MYSQL_CNF}"
trap 'rm -f "${MYSQL_CNF}"' EXIT

cat > "${MYSQL_CNF}" <<EOF
[client]
host=${DB_HOST}
port=${DB_PORT}
user=${DB_USER}
password=${DB_PASSWORD}
default-character-set=utf8mb4
EOF

echo "Backing up MySQL..."
mysqldump \
  --defaults-extra-file="${MYSQL_CNF}" \
  --single-transaction \
  --routines \
  --triggers \
  --no-tablespaces \
  "${DB_NAME}" > "${WORK_DIR}/daka_backup.sql"

echo "Packing backend code..."
tar -czf "${WORK_DIR}/daka-server-code.tar.gz" \
  --exclude=node_modules \
  --exclude=.env \
  --exclude=.git \
  -C "${APP_DIR}" .

echo "Copying environment file..."
cp "${ENV_FILE}" "${WORK_DIR}/env.server"
chmod 600 "${WORK_DIR}/env.server"

echo "Creating final bundle..."
tar -czf "${OUT_DIR}/daka-migration-${STAMP}.tar.gz" \
  -C "${WORK_DIR}" \
  daka_backup.sql \
  daka-server-code.tar.gz \
  env.server
chmod 600 "${OUT_DIR}/daka-migration-${STAMP}.tar.gz"

echo "Migration bundle ready:"
ls -lh "${OUT_DIR}/daka-migration-${STAMP}.tar.gz"
echo "Keep this file private. It contains database data and secrets."
