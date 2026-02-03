# 🦞 OpenClaw AWS Terraform

> One-command deployment of [OpenClaw](https://www.npmjs.com/package/openclaw) on AWS EC2 with Slack integration, S3 backups, and security hardening.

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-purple.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20S3%20%7C%20IAM-orange.svg)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 🎯 What This Does

Deploys a production-ready OpenClaw instance on AWS with:

- **EC2** (t3.medium) — 4GB RAM, Ubuntu 24.04
- **Security Group** — Restricted to your IP only
- **S3 Bucket** — Encrypted daily backups with lifecycle policies
- **IAM Role** — Secure EC2-to-S3 access (no hardcoded keys)
- **Elastic IP** — Static public IP
- **Slack Integration** — Pre-configured and ready to use
- **Systemd Service** — Auto-start on reboot

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

- AWS Account
- [Terraform](https://developer.hashicorp.com/terraform/downloads) (v1.0+)
- [AWS CLI](https://aws.amazon.com/cli/) (configured)
- Slack Bot Token (`xoxb-...`) and App Token (`xapp-...`)
- Anthropic API Key (`sk-ant-...`)

---

## 🚀 Quick Start

### 1. Clone this repo

```bash
git clone https://github.com/YOUR_USERNAME/openclaw-aws-terraform.git
cd openclaw-aws-terraform
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

# Your API keys (REQUIRED)
anthropic_api_key = "sk-ant-api03-xxxxx"
slack_bot_token   = "xoxb-xxxxx"
slack_app_token   = "xapp-xxxxx"
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

## 📁 Files

| File | Description |
|------|-------------|
| `main.tf` | AWS infrastructure (EC2, S3, IAM, Security Groups) |
| `variables.tf` | Input variable definitions |
| `outputs.tf` | Output values (IPs, URLs, commands) |
| `user_data.sh` | EC2 bootstrap script (installs OpenClaw via npm) |
| `terraform.tfvars.example` | Example configuration template |
| `SETUP_GUIDE.md` | Detailed step-by-step guide |

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
| `oc backup` | Manual backup to S3 |
| `oc restore <file>` | Restore from S3 backup |
| `oc update` | Update OpenClaw to latest |
| `oc url` | Show dashboard URL with token |
| `oc token` | Show gateway token |

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

- [OpenClaw npm package](https://www.npmjs.com/package/openclaw)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [AWS EC2 Pricing](https://aws.amazon.com/ec2/pricing/)

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
