# 🦞 OpenClaw Worker - AWS Terraform

> Production-ready Terraform configuration for deploying [OpenClaw](https://www.npmjs.com/package/openclaw) on AWS EC2 with Slack integration, automated backups, and enterprise security.

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-purple.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20S3%20%7C%20IAM-orange.svg)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/qodex-ai/openclaw-worker/actions/workflows/ci.yml/badge.svg)](https://github.com/qodex-ai/openclaw-worker/actions)

---

## ⚡ TL;DR

```bash
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
terraform apply  # Type 'yes'
terraform output -raw dashboard_url_with_token  # Copy this URL
```

Wait 5 minutes for setup, then open the URL. Done! ✅

For detailed instructions, see [SETUP_GUIDE.md](SETUP_GUIDE.md).

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

### 2. Get your public IP

```bash
curl ifconfig.me
```

### 3. Create your configuration

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region    = "us-east-1"
instance_type = "t3.medium"

# Your IP address (REQUIRED) - add /32 at the end
my_ip_cidrs = ["203.0.113.50/32"]

# Your Anthropic API key (REQUIRED)
anthropic_api_key = "sk-ant-api03-xxxxx"
```

### 4. Deploy

```bash
terraform init
terraform apply
```

Type `yes` when prompted. Wait ~5 minutes.

### 5. Get your dashboard URL

```bash
terraform output -raw dashboard_url_with_token
```

Open in browser — done! 🎉

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

### Can't connect to dashboard

1. Check your IP hasn't changed: `curl ifconfig.me`
2. Update `terraform.tfvars` with new IP
3. Run `terraform apply`

### OpenClaw not starting

```bash
# SSH in and check logs
$(terraform output -raw ssh_command)
oc logs

# Check bootstrap log
sudo cat /var/log/openclaw-bootstrap.log
```

### Slack not connecting

```bash
# SSH in and check config
$(terraform output -raw ssh_command)
cat ~/.openclaw/config.json

# Check logs for Slack errors
oc logs | grep -i slack
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
