#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="${APP_NAME:-tagify}"
APP_DIR="${APP_DIR:-/opt/tagify}"
BLUE_PORT="${BLUE_PORT:-4001}"
GREEN_PORT="${GREEN_PORT:-4002}"
NGINX_UPSTREAM_CONF="${NGINX_UPSTREAM_CONF:-/etc/nginx/conf.d/${APP_NAME}-upstream.conf}"
ENV_FILE="${APP_DIR}/${APP_NAME}.env"
LOG_DIR="/var/log/${APP_NAME}"
DEPLOY_LOG="${LOG_DIR}/deploy.log"
HEALTH_RETRIES="${HEALTH_RETRIES:-30}"
HEALTH_DELAY_SECONDS="${HEALTH_DELAY_SECONDS:-2}"

require_value() {
  local name="$1"
  local value="${!name:-}"

  if [ -z "$value" ]; then
    echo "${name} is required."
    exit 1
  fi
}

current_port() {
  if [ -f "$NGINX_UPSTREAM_CONF" ]; then
    grep -Eo '127\.0\.0\.1:[0-9]+' "$NGINX_UPSTREAM_CONF" | head -n1 | cut -d: -f2 || true
  fi
}

container_for_port() {
  local port="$1"

  if [ "$port" = "$BLUE_PORT" ]; then
    echo "${APP_NAME}-blue"
  else
    echo "${APP_NAME}-green"
  fi
}

login_to_ecr() {
  if ! command -v aws >/dev/null 2>&1; then
    return
  fi

  local registry
  registry="$(printf '%s' "$IMAGE_URI" | cut -d/ -f1)"

  if printf '%s' "$registry" | grep -q 'amazonaws.com'; then
    aws ecr get-login-password --region "${AWS_REGION:-us-east-1}" | docker login --username AWS --password-stdin "$registry"
  fi
}

write_env_file() {
  install -m 700 -d "$APP_DIR"

  cat > "$ENV_FILE" <<EOF
NODE_ENV=production
DB_URL=${DB_URL}
JWT_SECRET=${JWT_SECRET}
EOF

  chmod 600 "$ENV_FILE"
}

start_new_container() {
  docker pull "$IMAGE_URI"
  docker rm -f "$NEW_CONTAINER" >/dev/null 2>&1 || true

  docker run -d \
    --name "$NEW_CONTAINER" \
    --restart unless-stopped \
    --env-file "$ENV_FILE" \
    -e "PORT=${NEW_PORT}" \
    -p "127.0.0.1:${NEW_PORT}:${NEW_PORT}" \
    "$IMAGE_URI"
}

wait_for_health() {
  local attempt=1

  while [ "$attempt" -le "$HEALTH_RETRIES" ]; do
    if curl -fsS "http://127.0.0.1:${NEW_PORT}/health" >/dev/null; then
      return 0
    fi

    sleep "$HEALTH_DELAY_SECONDS"
    attempt=$((attempt + 1))
  done

  echo "New container did not become healthy."
  docker logs "$NEW_CONTAINER" || true
  exit 1
}

switch_nginx() {
  local tmp_file
  tmp_file="$(mktemp)"

  printf 'set $tagify_upstream http://127.0.0.1:%s;\n' "$NEW_PORT" > "$tmp_file"
  sudo mv "$tmp_file" "$NGINX_UPSTREAM_CONF"
  sudo nginx -t
  sudo systemctl reload nginx
}

stop_old_container() {
  if [ -n "${OLD_CONTAINER:-}" ] && [ "$OLD_CONTAINER" != "$NEW_CONTAINER" ]; then
    docker rm -f "$OLD_CONTAINER" >/dev/null 2>&1 || true
  fi
}

require_value IMAGE_URI

mkdir -p "$LOG_DIR"
touch "$DEPLOY_LOG"
exec > >(tee -a "$DEPLOY_LOG") 2>&1

echo "Starting deployment at $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Deploying image ${IMAGE_URI}"

if [ -n "${DB_URL_B64:-}" ]; then
  DB_URL="$(printf '%s' "$DB_URL_B64" | base64 -d)"
fi

if [ -n "${JWT_SECRET_B64:-}" ]; then
  JWT_SECRET="$(printf '%s' "$JWT_SECRET_B64" | base64 -d)"
fi

require_value DB_URL
require_value JWT_SECRET

ACTIVE_PORT="$(current_port)"

if [ "$ACTIVE_PORT" = "$BLUE_PORT" ]; then
  NEW_PORT="$GREEN_PORT"
  OLD_CONTAINER="$(container_for_port "$BLUE_PORT")"
else
  NEW_PORT="$BLUE_PORT"
  OLD_CONTAINER="$(container_for_port "$GREEN_PORT")"
fi

NEW_CONTAINER="$(container_for_port "$NEW_PORT")"

login_to_ecr
write_env_file
start_new_container
wait_for_health
switch_nginx
stop_old_container

echo "Deployed ${IMAGE_URI} to ${NEW_CONTAINER} on port ${NEW_PORT}."
echo "Finished deployment at $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
