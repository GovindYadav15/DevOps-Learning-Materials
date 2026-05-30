#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="${APP_NAME:-tagify}"
APP_DIR="${APP_DIR:-/opt/tagify}"
APP_USER="${APP_USER:-ec2-user}"
BLUE_PORT="${BLUE_PORT:-4001}"
GREEN_PORT="${GREEN_PORT:-4002}"
NGINX_CONF="/etc/nginx/conf.d/${APP_NAME}.conf"
NGINX_UPSTREAM_CONF="/etc/nginx/conf.d/${APP_NAME}-upstream.conf"
LOG_DIR="/var/log/${APP_NAME}"
DEPLOY_LOG="${LOG_DIR}/deploy.log"
CW_AGENT_CONFIG_SOURCE="${CW_AGENT_CONFIG_SOURCE:-}"
CW_AGENT_CONFIG_TARGET="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
CW_AGENT_CTL="/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"
SERVER_NAME="${SERVER_NAME:-_}"

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script with sudo."
    exit 1
  fi
}

install_packages() {
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y docker.io nginx curl unzip awscli
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y docker nginx curl unzip awscli
  elif command -v yum >/dev/null 2>&1; then
    yum install -y docker nginx curl unzip awscli
  else
    echo "Unsupported Linux distribution. Install Docker, Nginx, curl, and AWS CLI manually."
    exit 1
  fi
}

configure_services() {
  mkdir -p "$APP_DIR"
  mkdir -p "$LOG_DIR"
  touch "$DEPLOY_LOG"
  chown "$APP_USER":"$APP_USER" "$APP_DIR" || true
  chown "$APP_USER":"$APP_USER" "$LOG_DIR" "$DEPLOY_LOG" || true

  systemctl enable docker
  systemctl start docker
  usermod -aG docker "$APP_USER" || true

  cat > "$NGINX_UPSTREAM_CONF" <<EOF
set \$tagify_upstream http://127.0.0.1:${BLUE_PORT};
EOF

  cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name ${SERVER_NAME};

    include ${NGINX_UPSTREAM_CONF};

    location / {
        proxy_pass \$tagify_upstream;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /health {
        proxy_pass \$tagify_upstream/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
}
EOF

  nginx -t
  systemctl enable nginx
  systemctl restart nginx
}

install_cloudwatch_agent() {
  if command -v apt-get >/dev/null 2>&1; then
    local package_url="https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb"
    curl -fsSL "$package_url" -o /tmp/amazon-cloudwatch-agent.deb
    dpkg -i /tmp/amazon-cloudwatch-agent.deb
  elif command -v rpm >/dev/null 2>&1; then
    local package_url="https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm"
    curl -fsSL "$package_url" -o /tmp/amazon-cloudwatch-agent.rpm
    rpm -U /tmp/amazon-cloudwatch-agent.rpm || rpm -i /tmp/amazon-cloudwatch-agent.rpm
  fi
}

configure_cloudwatch_agent() {
  if [ ! -x "$CW_AGENT_CTL" ]; then
    install_cloudwatch_agent
  fi

  if [ -n "$CW_AGENT_CONFIG_SOURCE" ] && [ -f "$CW_AGENT_CONFIG_SOURCE" ]; then
    install -m 644 "$CW_AGENT_CONFIG_SOURCE" "$CW_AGENT_CONFIG_TARGET"
  elif [ ! -f "$CW_AGENT_CONFIG_TARGET" ]; then
    cat > "$CW_AGENT_CONFIG_TARGET" <<EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/${APP_NAME}/nginx/access",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/${APP_NAME}/nginx/error",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "${DEPLOY_LOG}",
            "log_group_name": "/${APP_NAME}/deploy",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "\${aws:InstanceId}"
    },
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60,
        "totalcpu": true
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF
  fi

  "$CW_AGENT_CTL" \
    -a fetch-config \
    -m ec2 \
    -c "file:${CW_AGENT_CONFIG_TARGET}" \
    -s
}

require_root
install_packages
configure_services
configure_cloudwatch_agent

echo "EC2 host is ready for ${APP_NAME} deployments."
echo "Use port 80 through Nginx. Blue/green app ports are ${BLUE_PORT} and ${GREEN_PORT}."
echo "CloudWatch Agent is collecting Nginx logs, deployment logs, CPU, memory, and disk metrics."
