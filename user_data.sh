#!/bin/bash
set -e
exec > >(tee /var/log/openclaw-bootstrap.log) 2>&1

echo "=========================================="
echo "OpenClaw Bootstrap Starting: $(date)"
echo "=========================================="

# Variables from Terraform
GATEWAY_TOKEN="${gateway_token}"
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"
ANTHROPIC_API_KEY="${anthropic_api_key}"

CONFIG_DIR="/home/ubuntu/.openclaw"
export HOME="/home/ubuntu"

# Update system
echo ">>> Updating system..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install packages
echo ">>> Installing packages..."
apt-get install -y curl wget git unzip ca-certificates gnupg lsb-release jq htop awscli

# Create swap (2GB) - useful even on t3.medium for peak loads
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

# Install Node.js 22 (required for openclaw)
echo ">>> Installing Node.js 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
node --version
npm --version

# Install Docker (still needed - openclaw uses it under the hood)
echo ">>> Installing Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker ubuntu
systemctl enable docker

# Install OpenClaw via npm
echo ">>> Installing OpenClaw via npm..."
npm install -g openclaw

# Create config directory
sudo -u ubuntu mkdir -p $CONFIG_DIR $CONFIG_DIR/workspace

# Create environment file
echo ">>> Creating configuration..."
cat > /home/ubuntu/.env << EOF
# OpenClaw Configuration - Generated $(date)

# Gateway
OPENCLAW_GATEWAY_TOKEN=$GATEWAY_TOKEN
OPENCLAW_GATEWAY_PORT=18789

# Directories
OPENCLAW_CONFIG_DIR=$CONFIG_DIR
OPENCLAW_WORKSPACE_DIR=$CONFIG_DIR/workspace

# S3 Backup
OPENCLAW_S3_BUCKET=$S3_BUCKET
AWS_REGION=$AWS_REGION

# Anthropic
ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
EOF

chown ubuntu:ubuntu /home/ubuntu/.env
chmod 600 /home/ubuntu/.env

# Create openclaw config file
sudo -u ubuntu cat > $CONFIG_DIR/config.json << EOF
{
  "gateway": {
    "token": "$GATEWAY_TOKEN",
    "port": 18789,
    "bind": "0.0.0.0"
  },
  "anthropic": {
    "apiKey": "$ANTHROPIC_API_KEY"
  }
}
EOF
chown ubuntu:ubuntu $CONFIG_DIR/config.json
chmod 600 $CONFIG_DIR/config.json

# Create management script
echo ">>> Creating management script..."
mkdir -p /home/ubuntu/bin
cat > /home/ubuntu/bin/oc << 'SCRIPT'
#!/bin/bash
set -a
[ -f ~/.env ] && source ~/.env
set +a

case "$1" in
    start)
        echo "Starting OpenClaw..."
        cd ~ && nohup openclaw up --token "$OPENCLAW_GATEWAY_TOKEN" > ~/.openclaw/openclaw.log 2>&1 &
        sleep 3
        echo "OpenClaw started. Check logs with: oc logs"
        ;;
    stop)
        echo "Stopping OpenClaw..."
        pkill -f "openclaw" || true
        docker stop $(docker ps -q --filter "name=openclaw") 2>/dev/null || true
        echo "OpenClaw stopped."
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        if pgrep -f "openclaw" > /dev/null; then
            echo "OpenClaw is running"
            docker ps --filter "name=openclaw"
        else
            echo "OpenClaw is not running"
        fi
        ;;
    logs)
        tail -f ~/.openclaw/openclaw.log
        ;;
    update)
        echo "Updating OpenClaw..."
        npm update -g openclaw
        $0 restart
        ;;
    backup)
        FILE="openclaw-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        echo "Creating backup: $FILE"
        tar -czvf "/tmp/$FILE" ~/.openclaw ~/.env 2>/dev/null
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
        echo "Downloading backup: $2"
        aws s3 cp "s3://$OPENCLAW_S3_BUCKET/backups/$2" "/tmp/$2"
        $0 stop
        tar -xzvf "/tmp/$2" -C /
        rm "/tmp/$2"
        $0 start
        echo "Restore complete!"
        ;;
    token)
        echo "$OPENCLAW_GATEWAY_TOKEN"
        ;;
    url)
        IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
        echo "http://$IP:18789/?token=$OPENCLAW_GATEWAY_TOKEN"
        ;;
    *)
        echo "OpenClaw Management"
        echo ""
        echo "Usage: oc <command>"
        echo ""
        echo "Commands:"
        echo "  start    - Start OpenClaw"
        echo "  stop     - Stop OpenClaw"
        echo "  restart  - Restart OpenClaw"
        echo "  status   - Check if running"
        echo "  logs     - View logs"
        echo "  update   - Update to latest version"
        echo "  backup   - Manual backup to S3"
        echo "  restore  - Restore from S3"
        echo "  token    - Show gateway token"
        echo "  url      - Show dashboard URL with token"
        ;;
esac
SCRIPT
chown ubuntu:ubuntu /home/ubuntu/bin/oc
chmod +x /home/ubuntu/bin/oc

# Add to PATH
echo 'export PATH="$HOME/bin:$PATH"' >> /home/ubuntu/.bashrc
echo 'source ~/.env 2>/dev/null' >> /home/ubuntu/.bashrc

# Create systemd service
echo ">>> Creating systemd service..."
cat > /etc/systemd/system/openclaw.service << EOF
[Unit]
Description=OpenClaw Gateway
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=ubuntu
Environment=HOME=/home/ubuntu
EnvironmentFile=/home/ubuntu/.env
WorkingDirectory=/home/ubuntu
ExecStart=/usr/bin/openclaw up --token \${OPENCLAW_GATEWAY_TOKEN}
ExecStop=/usr/bin/pkill -f openclaw
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable openclaw.service

# Start OpenClaw
echo ">>> Starting OpenClaw..."
systemctl start openclaw.service

# Wait for startup
sleep 10

# Save credentials file
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
cat > /home/ubuntu/CREDENTIALS.txt << EOF
═══════════════════════════════════════════════════════════════
                    OPENCLAW CREDENTIALS
═══════════════════════════════════════════════════════════════

Dashboard URL:
  http://$PUBLIC_IP:18789/?token=$GATEWAY_TOKEN

Gateway Token:
  $GATEWAY_TOKEN

S3 Backup Bucket:
  $S3_BUCKET

Quick Commands:
  oc start    - Start OpenClaw
  oc stop     - Stop OpenClaw
  oc restart  - Restart OpenClaw
  oc status   - Check status
  oc logs     - View logs
  oc backup   - Manual backup to S3
  oc url      - Show dashboard URL
  oc update   - Update OpenClaw

Note: Automated daily backups are disabled. Configure backups through OpenClaw.

═══════════════════════════════════════════════════════════════
EOF
chown ubuntu:ubuntu /home/ubuntu/CREDENTIALS.txt
chmod 600 /home/ubuntu/CREDENTIALS.txt

echo "=========================================="
echo "OpenClaw Bootstrap Complete: $(date)"
echo "Dashboard: http://$PUBLIC_IP:18789"
echo "=========================================="
