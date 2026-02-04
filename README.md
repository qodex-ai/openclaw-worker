# 🦞 OpenClaw Worker - AWS Terraform

> Production-ready Terraform configuration for deploying [OpenClaw](https://www.npmjs.com/package/openclaw) on AWS EC2 with Slack integration, automated backups, and enterprise security.

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-purple.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20S3%20%7C%20IAM-orange.svg)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/qodex-ai/openclaw-worker/actions/workflows/ci.yml/badge.svg)](https://github.com/qodex-ai/openclaw-worker/actions)

---

## ⚡ TL;DR

```bash
# Clone repository
git clone https://github.com/qodex-ai/openclaw-worker.git
cd openclaw-worker

# Setup AWS credentials
cp .aws.env.example .aws.env
nano .aws.env  # Add your AWS access key and secret key
source .aws.env

# Configure Terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Add your IP and Anthropic API key

# Deploy
terraform init
terraform apply  # Type 'yes' when prompted

# Wait 5-8 minutes for bootstrap, then get dashboard URL
terraform output -raw dashboard_url_with_token
```

Open the URL in your browser. Done! ✅

For detailed instructions, see [SETUP_GUIDE.md](SETUP_GUIDE.md).

### 📝 After Deployment

After successful deployment, create a `LOCAL_README.md` file (git-ignored) to store your actual configuration:
- EC2 instance details, SSH keys, IP addresses
- Dashboard URLs with tokens
- S3 bucket names
- Quick reference commands with your real values

See the template at the end of this README.

---

## 🎯 What This Does

This Terraform configuration automatically deploys a production-ready OpenClaw instance on AWS with enterprise-grade security and automation:

### Infrastructure Components

- **EC2 Instance** (t3.medium) — 4GB RAM, Ubuntu 24.04 LTS, auto-updates enabled
- **Security Group** — Locked down to your IP only (SSH + Dashboard)
- **S3 Bucket** — Encrypted backups with automatic cleanup (180 days retention)
- **IAM Role & Instance Profile** — Secure EC2-to-S3 access without hardcoded credentials
- **Elastic IP** — Static public IP that persists across restarts
- **SSH Key Pair** — Auto-generated 4096-bit RSA key
- **SSM Integration** — AWS Systems Manager for secure access

### Software Stack

- **Node.js 22** — Latest LTS version
- **OpenClaw** — Installed via npm for easy updates
- **Docker** — Required for OpenClaw's container management
- **Systemd Service** — Auto-start on boot with automatic restarts
- **Management CLI** — Custom `oc` command for operations

### Automation

- **User Data Script** — Automated installation and configuration
- **Manual Backups** — On-demand backup to S3 via `oc backup` command
- **S3 Lifecycle Policy** — Automatic deletion after 180 days
- **GitHub Actions** — CI/CD with Terraform validation and security scanning

**Note**: Configure automated backups through OpenClaw's interface using your AWS credentials.

```
┌─────────────────────────────────────────────────────────────────┐
│                      ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   YOUR IP ─────────►  EC2 (t3.medium)                           │
│   (SSH + Dashboard)    ├── Node.js 22                           │
│                        ├── OpenClaw (npm)                        │
│                        ├── Docker                                │
│                        └── Slack ◄──────► Slack API             │
│                              │                                   │
│                              ▼                                   │
│                         S3 Bucket                                │
│                    (encrypted backups)                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 💰 Cost

| Resource | Monthly Cost |
|----------|-------------|
| EC2 t3.medium | ~$30 |
| EBS 20GB | ~$2 |
| S3 backups | ~$1 |
| **Total** | **~$33/month** |

---

## 📋 Prerequisites

- **AWS Account** with IAM user access keys
- **[Terraform](https://developer.hashicorp.com/terraform/downloads)** (v1.0+)
- **[AWS CLI](https://aws.amazon.com/cli/)** installed
- **Anthropic API Key** (`sk-ant-...`)

**Note**: This setup uses environment variables (`.aws.env` file) for AWS credentials instead of `aws configure`. This keeps credentials project-local and git-ignored. Slack integration is configured through OpenClaw's interface after deployment.

---

## 🚀 Quick Start

### 1. Clone this repo

```bash
git clone https://github.com/qodex-ai/openclaw-worker.git
cd openclaw-worker
```

### 2. Setup AWS Credentials

```bash
cp .aws.env.example .aws.env
nano .aws.env
```

Add your AWS credentials:
```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1
```

Load credentials:
```bash
source .aws.env
aws sts get-caller-identity  # Verify they work
```

### 3. Get Your Public IP

```bash
curl -4 ifconfig.me  # Returns your IPv4 address
```

### 4. Configure Terraform Variables

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Edit with your values:
```hcl
aws_region    = "us-east-1"
instance_type = "t3.medium"

# Your IP (add /32 at the end)
my_ip_cidrs = ["49.47.128.13/32"]

# Your Anthropic API key
anthropic_api_key = "sk-ant-api03-xxxxx"
```

### 5. Deploy Infrastructure

```bash
terraform init
terraform apply
```

Type `yes` when prompted. Wait ~3 minutes for AWS resources.

### 6. Wait for Bootstrap & Get Dashboard URL

The EC2 instance will auto-install OpenClaw (5-8 minutes). Then:

```bash
terraform output -raw dashboard_url_with_token
```

Open the URL in your browser — done! 🎉

**Note**: Configure Slack and S3 backups through OpenClaw's dashboard after deployment.

---

## 📁 Repository Contents

| File/Directory | Description |
|----------------|-------------|
| `main.tf` | Core AWS infrastructure (EC2, S3, IAM, Security Groups, Elastic IP) |
| `variables.tf` | Input variable definitions and validation |
| `outputs.tf` | Output values (IPs, URLs, SSH commands, tokens) |
| `user_data.sh` | EC2 bootstrap script - installs Node.js, Docker, and OpenClaw via npm |
| `terraform.tfvars.example` | Template for Terraform variables (copy to `terraform.tfvars`) |
| `.aws.env.example` | Template for AWS credentials (copy to `.aws.env`) |
| `SETUP_GUIDE.md` | Complete step-by-step deployment guide (~45 minutes) |
| `.github/workflows/ci.yml` | Automated Terraform validation and security scanning |
| `.gitignore` | Git ignore rules for Terraform and sensitive files |
| `LICENSE` | MIT License (2025 Qodex AI) |

---

## 🔒 Security Features

- **IP Restriction** — Only your IP can access SSH (22) and dashboard (18789)
- **IMDSv2** — Instance metadata service v2 required
- **Encrypted EBS** — Root volume encrypted at rest
- **Encrypted S3** — AES-256 server-side encryption
- **No Public S3** — Bucket blocks all public access
- **IAM Role** — EC2 uses role-based access (no hardcoded credentials)
- **Token Auth** — 48-character random gateway token

---

## 🛠️ Management Commands

SSH into your instance:

```bash
$(terraform output -raw ssh_command)
```

Then use the `oc` command:

| Command | Description |
|---------|-------------|
| `oc status` | Check if OpenClaw is running |
| `oc logs` | View logs (follow mode) |
| `oc restart` | Restart OpenClaw |
| `oc stop` | Stop OpenClaw |
| `oc start` | Start OpenClaw |
| `oc backup` | Manual backup to S3 (on-demand only) |
| `oc restore <file>` | Restore from S3 backup |
| `oc update` | Update OpenClaw to latest |
| `oc url` | Show dashboard URL with token |
| `oc token` | Show gateway token |

**Note**: Automated daily backups are disabled. Configure backups within OpenClaw using your AWS credentials.

---

## 🔄 Common Operations

### Update your IP address

If your IP changes:

```bash
# Edit terraform.tfvars with new IP
nano terraform.tfvars

# Apply changes (instant, no restart)
terraform apply
```

### Update OpenClaw

```bash
# SSH into server
$(terraform output -raw ssh_command)

# Update
oc update
```

### View backups

```bash
aws s3 ls s3://$(terraform output -raw s3_bucket)/backups/
```

### Restore from backup

```bash
# SSH into server
$(terraform output -raw ssh_command)

# List backups
oc restore

# Restore specific backup
oc restore openclaw-backup-20240115.tar.gz
```

---

## 📊 Outputs

After deployment, these outputs are available:

```bash
terraform output                              # All outputs
terraform output instance_public_ip           # Server IP
terraform output ssh_command                  # SSH command
terraform output -raw dashboard_url_with_token # Dashboard URL
terraform output -raw gateway_token           # Just the token
terraform output s3_bucket                    # Backup bucket name
```

---

## 🗑️ Cleanup

To destroy all resources:

```bash
# Download backups first (optional)
aws s3 sync s3://$(terraform output -raw s3_bucket) ./my-backups/

# Destroy everything
terraform destroy
```

---

## ⚙️ Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `instance_type` | `t3.medium` | EC2 instance type |
| `my_ip_cidrs` | — | Your IP(s) for access (required) |
| `anthropic_api_key` | — | Anthropic API key (required) |
| `slack_bot_token` | — | Slack bot token (required) |
| `slack_app_token` | — | Slack app token (required) |

---

## 🔧 Customization

### Use a different instance type

```hcl
instance_type = "t3.small"   # $15/month, 2GB RAM
instance_type = "t3.medium"  # $30/month, 4GB RAM (default)
instance_type = "t3.large"   # $60/month, 8GB RAM
```

### Allow multiple IPs

```hcl
my_ip_cidrs = [
  "203.0.113.50/32",   # Home
  "198.51.100.25/32",  # Office
]
```

### Use a different region

```hcl
aws_region = "eu-west-1"  # Ireland
aws_region = "ap-south-1" # Mumbai
```

---

## 🐛 Troubleshooting

### Terraform: "Failed to load plugin schemas" (macOS)

If you get a timeout error with AWS provider on macOS:

```bash
# Remove Gatekeeper quarantine from Terraform providers
xattr -r -d com.apple.quarantine .terraform/providers/

# Then retry
terraform plan
```

This happens because macOS Gatekeeper blocks unsigned provider binaries.

### AWS Credentials Not Working

```bash
# Test credentials
source .aws.env
aws sts get-caller-identity

# If it fails, verify the .env file has 'export' statements:
cat .aws.env  # Should show: export AWS_ACCESS_KEY_ID=...
```

### Can't Connect to Dashboard

1. Check your IP hasn't changed: `curl -4 ifconfig.me`
2. Update `terraform.tfvars` with new IP
3. Run `terraform apply`

### OpenClaw Not Starting

```bash
# SSH into server
$(terraform output -raw ssh_command)

# Check service status
oc status

# View logs
oc logs

# Check bootstrap log
sudo cat /var/log/openclaw-bootstrap.log
```

### Manual Backup Not Working

Ensure the EC2 instance has S3 access (IAM role automatically configured by Terraform).

### Bootstrap Fails: "Package 'awscli' has no installation candidate"

**Fixed in latest version.** If you encounter this with an older version:

**Problem:** Ubuntu 24.04 doesn't have `awscli` in default apt repositories.

**Solution:** The `user_data.sh` script now installs AWS CLI v2 directly from Amazon. Update to the latest version:
```bash
git pull origin main
terraform init -upgrade
terraform apply
```

If you need to fix a running instance manually:
```bash
ssh -i openclaw-key.pem ubuntu@<your-ip>
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt-get install -y unzip
unzip -q awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
aws --version
```

### Terraform Hangs on Apple Silicon (M3/M2/M1)

**Problem:** Terraform stuck for hours during apply on Apple Silicon Macs.

**Root Cause:** Intel x86_64 Terraform running under Rosetta causes AWS provider crashes.

**Solution:** Use ARM64 native Terraform:
```bash
# Uninstall Intel version
brew uninstall terraform

# Download ARM64 version
cd ~/Downloads
wget https://releases.hashicorp.com/terraform/1.14.4/terraform_1.14.4_darwin_arm64.zip
unzip terraform_1.14.4_darwin_arm64.zip

# Install to ~/bin
mkdir -p ~/bin
mv terraform ~/bin/
chmod +x ~/bin/terraform

# Add to PATH (add this to ~/.zshrc for persistence)
export PATH="$HOME/bin:$PATH"

# Verify
terraform --version
file ~/bin/terraform  # Should show: Mach-O 64-bit executable arm64

# Reinitialize to get ARM64 providers
cd ~/Projects/flinket/jarvis/openclaw-worker
rm -rf .terraform
terraform init
terraform apply
```

---

## 📚 Resources

- **This Repository**: [qodex-ai/openclaw-worker](https://github.com/qodex-ai/openclaw-worker)
- [OpenClaw npm package](https://www.npmjs.com/package/openclaw)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [AWS EC2 Pricing](https://aws.amazon.com/ec2/pricing/)
- [Complete Setup Guide](SETUP_GUIDE.md) - Step-by-step instructions

---

## 📝 LOCAL_README.md Template

After deployment, create a `LOCAL_README.md` file (automatically git-ignored) to store your actual configuration values:

```bash
# Create your local documentation
nano LOCAL_README.md
```

**What to include:**
- EC2 instance ID, public IP, SSH key path
- Dashboard URL with token
- S3 bucket name
- Actual Terraform commands with your values
- AWS credentials reference
- Quick reference commands for daily use

**Example structure:**
```markdown
# My OpenClaw Deployment

## Instance Info
- Instance ID: i-xxxxx
- Public IP: x.x.x.x
- Dashboard: http://x.x.x.x:18789/?token=xxxxx

## Quick Commands
ssh -i openclaw-key.pem ubuntu@x.x.x.x
terraform output -raw dashboard_url_with_token
aws s3 ls s3://my-bucket/backups/

## Credentials
- AWS Account: 123456789012
- S3 Bucket: my-openclaw-backups-xxx
- Anthropic Key: sk-ant-xxx...
```

This keeps your actual values separate from version control while maintaining easy access to deployment details.

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## 📄 License

[MIT License](LICENSE) — feel free to use, modify, and distribute.

---

## ⭐ Star History

If this helped you, please star the repo!

---

Made with ❤️ for the OpenClaw community
