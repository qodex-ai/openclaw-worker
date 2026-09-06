#!/bin/bash
# OpenClaw box provisioning. Rendered by Terraform (templatefile): dollar-brace is
# Terraform interpolation, so bash variables here are written without braces.
set -euo pipefail
exec > >(tee /var/log/openclaw-bootstrap.log) 2>&1

echo "=========================================="
echo "OpenClaw Bootstrap Starting: $(date)"
echo "=========================================="

# Variables from Terraform
GATEWAY_TOKEN="${gateway_token}"
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"
ANTHROPIC_API_KEY="${anthropic_api_key}"
DOMAIN_NAME="${domain_name}"
EMAIL="${email}"
OPENCLAW_VERSION="${openclaw_version}"
NODE_MIN="${node_min_version}"

CONFIG_DIR="/home/ubuntu/.openclaw"
PLUGIN_DIR="$CONFIG_DIR/npm"
COMPILE_CACHE="/var/tmp/openclaw-compile-cache"
export HOME="/home/ubuntu"

fail() { echo "!!! BOOTSTRAP FAILED: $*" >&2; exit 1; }

# Instance metadata. IMDSv2 is required on this instance, so every read takes a
# session token first. This is the only place the metadata address appears.
imds() {
    local token
    token=$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 300") || return 1
    curl -fsS -H "X-aws-ec2-metadata-token: $token" \
        "http://169.254.169.254/latest/meta-data/$1"
}

# Update system
echo ">>> Updating system..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install packages.
# dnsutils: the certificate step waits on dig. python3-yaml: canon's apply_cron.py
# and check_manifest.py import it, so the bootstrap script does not have to.
echo ">>> Installing packages..."
apt-get install -y curl wget git unzip ca-certificates gnupg lsb-release jq htop dnsutils python3-yaml python3-pip

# Install AWS CLI v2
echo ">>> Installing AWS CLI v2..."
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip
cd -

# Create swap (2GB)
echo ">>> Creating swap..."
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    sysctl vm.swappiness=10
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
fi

# Install Node.js 22 from the NodeSource channel and enforce the floor.
# OpenClaw 2026.9 refuses to start below 22.22.3, and it fails at runtime rather
# than at install time, so assert here where the failure is visible in the log.
echo ">>> Installing Node.js 22 (floor $NODE_MIN)..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
NODE_VERSION=$(node --version | tr -d 'v')
echo "    node $NODE_VERSION, npm $(npm --version)"
if [ "$(printf '%s\n%s\n' "$NODE_MIN" "$NODE_VERSION" | sort -V | head -1)" != "$NODE_MIN" ]; then
    fail "node $NODE_VERSION is older than the $NODE_MIN floor required by OpenClaw $OPENCLAW_VERSION"
fi

# Install Docker.
# Kept because plugin sandboxes may still shell out to it, but the gateway unit
# only Wants= it: a docker failure must not keep OpenClaw down.
echo ">>> Installing Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker ubuntu
systemctl enable docker

# Install nginx and certbot. The site is HTTP-only for now; certbot adds TLS
# once DNS points here. Nothing may reference a certificate before that.
echo ">>> Installing nginx and certbot..."
apt-get install -y nginx certbot python3-certbot-nginx
systemctl enable nginx

# Install the Gmail CLI the canon skills call.
# tooling.md only points at https://gogcli.sh for the Linux install, so this uses
# the vendor installer and is non-fatal: the MOTD tells the operator to check.
echo ">>> Installing gog (gogcli)..."
if ! curl -fsSL https://gogcli.sh/install.sh | bash -s -- --bin-dir /usr/local/bin; then
    echo "!!! gog install failed; install it by hand, see canon tooling.md"
fi
command -v gog >/dev/null 2>&1 && gog --version || true

# Install OpenClaw, pinned.
echo ">>> Installing OpenClaw $OPENCLAW_VERSION..."
npm install -g "openclaw@$OPENCLAW_VERSION"
[ "$(openclaw --version 2>/dev/null | tr -d 'v')" = "$OPENCLAW_VERSION" ] || echo "!!! openclaw --version does not report $OPENCLAW_VERSION"

# Config, plugin and cache dirs
sudo -u ubuntu mkdir -p "$CONFIG_DIR" "$CONFIG_DIR/workspace" "$PLUGIN_DIR"
mkdir -p "$COMPILE_CACHE"
chown ubuntu:ubuntu "$COMPILE_CACHE"

# Plugins live in their own npm root, at the same version as the core, or the
# gateway loads a mismatched build and the plugin silently does nothing.
echo ">>> Installing plugins at $OPENCLAW_VERSION..."
[ -f "$PLUGIN_DIR/package.json" ] || (cd "$PLUGIN_DIR" && sudo -u ubuntu -H npm init -y)
sudo -u ubuntu -H npm install --prefix "$PLUGIN_DIR" \
    "@openclaw/slack@$OPENCLAW_VERSION" \
    "@openclaw/acpx@$OPENCLAW_VERSION" \
    "@openclaw/brave-plugin@$OPENCLAW_VERSION" \
    "@martian-engineering/lossless-claw"

# acpx and lossless-claw declare capabilities that need explicit consent.
sudo -u ubuntu -H openclaw plugins enable acpx --accept-capabilities
sudo -u ubuntu -H openclaw plugins enable lossless-claw --accept-capabilities

# Environment file. It is the systemd unit's EnvironmentFile and is also sourced
# by interactive shells, so doctor run from a shell sees the same repair policy.
echo ">>> Creating configuration..."
cat > /home/ubuntu/.env << EOF
# OpenClaw Configuration - Generated $(date)

# Gateway
OPENCLAW_GATEWAY_TOKEN=$GATEWAY_TOKEN
OPENCLAW_GATEWAY_PORT=18789

# Directories
OPENCLAW_CONFIG_DIR=$CONFIG_DIR
OPENCLAW_WORKSPACE_DIR=$CONFIG_DIR/workspace

# Public hostname, used by "oc url"
OPENCLAW_DOMAIN=$DOMAIN_NAME

# Our system unit owns the gateway lifecycle. Without these, openclaw doctor
# refuses to run and OpenClaw tries to respawn itself alongside systemd.
OPENCLAW_SERVICE_REPAIR_POLICY=external
OPENCLAW_SYSTEMD_UNIT=openclaw.service

# S3 Backup
OPENCLAW_S3_BUCKET=$S3_BUCKET
AWS_REGION=$AWS_REGION

# Anthropic
ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
EOF

chown ubuntu:ubuntu /home/ubuntu/.env
chmod 600 /home/ubuntu/.env

# openclaw.json, 2026.9 key layout.
#
# tools.profile = "coding": isolated sessions (cron jobs included) otherwise run
# under the "messaging" profile, which strips exec and filesystem tools, and every
# job degrades to a fake "ok".
# codeMode adds ~7s of session setup and times out cron under load.
# heartbeat 0m: 2026.9 schedules its own heartbeat runs, which spend the plan.
cat > "$CONFIG_DIR/openclaw.json" << EOF
{
  "gateway": {
    "mode": "local",
    "auth": {
      "token": "$GATEWAY_TOKEN"
    },
    "port": 18789,
    "controlUi": {
      "allowedOrigins": ["https://$DOMAIN_NAME"]
    }
  },
  "tools": {
    "profile": "coding"
  },
  "agents": {
    "entries": {
      "main": {
        "tools": {
          "codeMode": {
            "enabled": false
          }
        }
      }
    },
    "defaults": {
      "heartbeat": {
        "every": "0m"
      },
      "models": {
        "openai/gpt-5.5": {
          "agentRuntime": {
            "id": "openclaw"
          }
        },
        "openai/gpt-5.4-mini": {
          "agentRuntime": {
            "id": "openclaw"
          }
        }
      }
    }
  }
}
EOF
chown ubuntu:ubuntu "$CONFIG_DIR/openclaw.json"
chmod 600 "$CONFIG_DIR/openclaw.json"

# Management script
echo ">>> Creating management script..."
mkdir -p /home/ubuntu/bin
cat > /home/ubuntu/bin/oc << 'SCRIPT'
#!/bin/bash
set -a
[ -f ~/.env ] && source ~/.env
set +a

case "$1" in
    start)   sudo systemctl start openclaw.service && systemctl status --no-pager openclaw.service ;;
    stop)    sudo systemctl stop openclaw.service ;;
    restart) sudo systemctl restart openclaw.service && systemctl status --no-pager openclaw.service ;;
    status)  systemctl status --no-pager openclaw.service ;;
    logs)    journalctl -u openclaw.service -f ;;
    update)
        if [ -z "$2" ]; then echo "Usage: oc update <version>"; exit 1; fi
        sudo systemctl stop openclaw.service
        sudo npm install -g "openclaw@$2"
        npm install --prefix ~/.openclaw/npm \
            "@openclaw/slack@$2" "@openclaw/acpx@$2" "@openclaw/brave-plugin@$2"
        openclaw doctor --fix --non-interactive
        sudo systemctl start openclaw.service
        ;;
    backup)
        FILE="openclaw-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        echo "Creating backup: $FILE"
        tar -czf "/tmp/$FILE" --exclude='node_modules' --exclude='*.deleted.*' ~/.openclaw ~/.env 2>/dev/null
        aws s3 cp "/tmp/$FILE" "s3://$OPENCLAW_S3_BUCKET/backups/$FILE"
        rm "/tmp/$FILE"
        echo "Backup uploaded: s3://$OPENCLAW_S3_BUCKET/backups/$FILE"
        ;;
    restore)
        if [ -z "$2" ]; then
            echo "Usage: oc restore <backup-file.tar.gz>"
            echo "Available backups:"
            aws s3 ls "s3://$OPENCLAW_S3_BUCKET/backups/"
            exit 1
        fi
        aws s3 cp "s3://$OPENCLAW_S3_BUCKET/backups/$2" "/tmp/$2"
        sudo systemctl stop openclaw.service
        tar -xzf "/tmp/$2" -C /
        rm "/tmp/$2"
        sudo systemctl start openclaw.service
        echo "Restore complete."
        ;;
    token)   echo "$OPENCLAW_GATEWAY_TOKEN" ;;
    url)     echo "https://$OPENCLAW_DOMAIN/?token=$OPENCLAW_GATEWAY_TOKEN" ;;
    *)
        echo "OpenClaw Management"
        echo ""
        echo "Usage: oc <command>"
        echo ""
        echo "  start | stop | restart | status | logs"
        echo "  update <version>  - pin core + plugins to a version, run doctor"
        echo "  backup            - manual backup to S3"
        echo "  restore <file>    - restore from S3"
        echo "  token             - show gateway token"
        echo "  url               - dashboard URL with token"
        ;;
esac
SCRIPT
chown ubuntu:ubuntu /home/ubuntu/bin/oc
chmod +x /home/ubuntu/bin/oc

# Shell PATH and env
echo 'export PATH="$HOME/bin:$PATH"' >> /home/ubuntu/.bashrc
echo 'set -a; [ -f ~/.env ] && source ~/.env; set +a' >> /home/ubuntu/.bashrc

# systemd unit. System-level and ubuntu-owned; 2026.9 prefers a user unit but
# supports this with OPENCLAW_SERVICE_REPAIR_POLICY=external.
echo ">>> Creating systemd service..."
cat > /etc/systemd/system/openclaw.service << EOF
[Unit]
Description=OpenClaw Gateway
After=network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=simple
User=ubuntu
Environment=HOME=/home/ubuntu
Environment=OPENCLAW_SERVICE_REPAIR_POLICY=external
Environment=OPENCLAW_SYSTEMD_UNIT=openclaw.service
Environment=OPENCLAW_NO_RESPAWN=1
Environment=NODE_COMPILE_CACHE=$COMPILE_CACHE
EnvironmentFile=/home/ubuntu/.env
WorkingDirectory=/home/ubuntu
ExecStart=/usr/bin/openclaw gateway --port 18789 --bind lan
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable openclaw.service

echo ">>> Starting OpenClaw..."
systemctl start openclaw.service
sleep 15

# Settings that have a config command. Hand edits to openclaw.json are dropped on
# restart, so re-assert these through the CLI once the gateway is up. Non-fatal:
# the JSON above already carries them and the MOTD asks the operator to verify.
echo ">>> Asserting config through the CLI..."
sudo -u ubuntu -H openclaw config set tools.profile coding || echo "!!! config set tools.profile failed"
sudo -u ubuntu -H openclaw config set agents.defaults.heartbeat.every 0m || echo "!!! config set heartbeat failed"
sudo -u ubuntu -H openclaw config set agents.defaults.models \
    '{"openai/gpt-5.5":{"agentRuntime":{"id":"openclaw"}},"openai/gpt-5.4-mini":{"agentRuntime":{"id":"openclaw"}}}' \
    --strict-json --merge || echo "!!! config set models failed, set it by hand"

# nginx, HTTP only, and it proxies nothing yet. Port 80 is open to the world for
# the ACME challenge, so the gateway must not be reachable on it. The proxy is
# added below, on 443, once the certificate exists.
echo ">>> Configuring nginx (HTTP, ACME only)..."
cat > /etc/nginx/sites-available/openclaw << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 404;
    }
}
EOF

ln -sf /etc/nginx/sites-available/openclaw /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx

# Certificate. Only once DNS actually points at this instance: certbot's HTTP-01
# challenge fails otherwise and burns a Let's Encrypt rate-limit slot.
PUBLIC_IP=$(imds public-ipv4 || echo "")
echo ">>> Waiting for $DOMAIN_NAME to resolve to $PUBLIC_IP (up to 15 minutes)..."
DNS_OK=no
for i in $(seq 1 90); do
    RESOLVED=$(dig +short "$DOMAIN_NAME" A | tail -1)
    if [ -n "$PUBLIC_IP" ] && [ "$RESOLVED" = "$PUBLIC_IP" ]; then
        DNS_OK=yes
        echo "    resolved after $((i * 10))s"
        break
    fi
    sleep 10
done

CERT_OK=no
if [ "$DNS_OK" = "yes" ]; then
    echo ">>> Obtaining certificate..."
    # certonly: take the certificate, leave the nginx config to us. Renewal uses
    # the same nginx authenticator, which is why port 80 stays open.
    if certbot certonly --nginx --non-interactive --agree-tos \
        --email "$EMAIL" --domains "$DOMAIN_NAME"; then
        CERT_OK=yes
    else
        echo "!!! certbot failed"
    fi
else
    echo "!!! $DOMAIN_NAME did not resolve to $PUBLIC_IP in 15 minutes; skipping certbot."
fi

if [ "$CERT_OK" = "yes" ]; then
    echo ">>> Enabling HTTPS..."
    cat > /etc/nginx/sites-available/openclaw << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    http2 on;
    server_name $DOMAIN_NAME;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://localhost:18789;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }
}
EOF
    nginx -t
    systemctl reload nginx
    systemctl enable certbot.timer
    systemctl start certbot.timer
    echo "    HTTPS enabled"
else
    echo "!!! No certificate. nginx serves the ACME path and 404 for everything else,"
    echo "!!! so the gateway is not exposed on port 80. To finish by hand:"
    echo "!!!   certbot certonly --nginx -d $DOMAIN_NAME"
    echo "!!! then re-run this block, or edit /etc/nginx/sites-available/openclaw."
fi

# Daily backup
echo ">>> Setting up automated daily backups..."
sudo -u ubuntu crontab -l 2>/dev/null > /tmp/crontab_temp || true
echo "# Automated daily backup to S3 at 2 AM UTC" >> /tmp/crontab_temp
echo "0 2 * * * bash -l -c '/home/ubuntu/bin/oc backup >> /home/ubuntu/.openclaw/backup.log 2>&1'" >> /tmp/crontab_temp
sudo -u ubuntu crontab /tmp/crontab_temp
rm /tmp/crontab_temp

# Credentials
cat > /home/ubuntu/CREDENTIALS.txt << EOF
OPENCLAW CREDENTIALS

Dashboard (HTTPS, once the certificate is issued):
  https://$DOMAIN_NAME/?token=$GATEWAY_TOKEN

Dashboard (direct HTTP):
  http://$PUBLIC_IP:18789/?token=$GATEWAY_TOKEN

Gateway token:
  $GATEWAY_TOKEN

S3 backup bucket:
  $S3_BUCKET

OpenClaw version: $OPENCLAW_VERSION
Commands: oc start|stop|restart|status|logs|update|backup|restore|token|url
Backups: daily at 2 AM UTC. Log: ~/.openclaw/backup.log
EOF
chown ubuntu:ubuntu /home/ubuntu/CREDENTIALS.txt
chmod 600 /home/ubuntu/CREDENTIALS.txt

# The remaining steps need a human: a deploy key, and two device logins that Sid
# approves. Nothing here can clone canon, so say so where the operator lands.
cat > /etc/motd << EOF

OpenClaw $OPENCLAW_VERSION provisioned by Terraform. Manual steps remain:

  1. Add this box's SSH public key as a deploy key on the canon repo:
       ssh-keygen -t ed25519 -C openclaw-box -f ~/.ssh/id_ed25519 -N ""
       cat ~/.ssh/id_ed25519.pub    # add at github.com/flinket/canon deploy keys
  2. Bootstrap canon:
       git clone --depth 1 git@github.com:flinket/canon.git /tmp/canon-boot \\
         && bash /tmp/canon-boot/ops/openclaw/bootstrap.sh main
  3. Two device logins, both approved by Sid, both need a TTY (ssh -tt):
       codex login --device-auth
       openclaw models auth login --provider openai --device-code
  4. Verify the config the CLI wrote:
       openclaw config get tools.profile agents.defaults.models
  5. Apply the schedule:
       cd /home/ubuntu/canon && python3 ops/openclaw/apply_cron.py --apply
  6. Enable the pull timer last:
       sudo systemctl enable --now canon-pull.timer

  Runbook: canon ops/openclaw/RUNBOOK.md. Credentials: ~/CREDENTIALS.txt.
  Bootstrap log: /var/log/openclaw-bootstrap.log

EOF

echo "=========================================="
echo "OpenClaw Bootstrap Complete: $(date)"
echo "Dashboard: http://$PUBLIC_IP:18789"
echo "=========================================="
