# 🦞 OpenClaw on AWS — Complete Setup Guide

> **Time**: ~45 minutes
> **Cost**: ~$33/month (t3.medium)
> **Channel**: Slack
> **Install**: OpenClaw via npm (Docker installed for internal use only)

---

## 📦 What Gets Created

```
┌─────────────────────────────────────────────────────────────────┐
│                         YOUR SETUP                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   YOUR IP ONLY ──────►  EC2 (t3.medium, 4GB RAM)                │
│   (SSH + Dashboard)      ├── Node.js 22 + npm                   │
│                          ├── OpenClaw (via npm)                  │
│                          ├── Docker (for openclaw internals)     │
│                          └── Manual backups ─────► S3 Bucket    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 What You Need

Before starting, gather these:

- ✅ **AWS Account** (will create in Part 1 if needed)
- ✅ **Anthropic API Key** (`sk-ant-...`)

**Note**: Slack integration is configured through OpenClaw's interface after deployment.

## 🔐 Security Note

This guide uses a `.env` file approach for AWS credentials instead of `aws configure`. Benefits:

- ✅ Credentials stored locally in project directory
- ✅ Easy to switch between different AWS accounts
- ✅ Git-ignored by default (won't accidentally commit)
- ✅ Works seamlessly with Terraform
- ✅ No global configuration changes

---

# PART 1: Create AWS Account
*Skip if you already have an AWS account*

## Step 1.1: Sign Up

1. Go to **https://aws.amazon.com**
2. Click **"Create an AWS Account"**
3. Enter email + account name
4. Verify email with code

## Step 1.2: Complete Registration

1. Create strong root password → **Save in password manager**
2. Select **"Personal"** account type
3. Enter contact info
4. Enter credit card ($1 verification charge, refunded)
5. Verify phone via SMS
6. Select **"Basic support - Free"**
7. Click **"Complete sign up"**

⏳ Wait for activation email (5-10 minutes)

---

# PART 2: Secure Your AWS Account

## Step 2.1: Enable MFA on Root Account

1. Sign in at **https://console.aws.amazon.com** (Root user)
2. Click account name (top right) → **"Security credentials"**
3. Find **"Multi-factor authentication (MFA)"**
4. Click **"Assign MFA device"**
5. Name: `root-mfa`, Type: **Authenticator app**
6. Scan QR with authenticator app
7. Enter two consecutive codes
8. Click **"Add MFA"**

✅ Root secured

---

# PART 3: Create IAM Admin User

## Step 3.1: Create User

1. Search **"IAM"** in console → Click it
2. **Users** → **Create user**
3. User name: `admin`
4. ✅ Check **"Provide user access to AWS Management Console"**
5. Select **"I want to create an IAM user"**
6. Create password → **Next**

## Step 3.2: Set Permissions

1. Select **"Attach policies directly"**
2. Search & check ✅ **"AdministratorAccess"**
3. **Next** → **Create user**

## Step 3.3: Create Access Keys

1. Click user **"admin"**
2. **Security credentials** tab
3. **Create access key**
4. Select **"Command Line Interface (CLI)"**
5. Check box → **Next** → **Create access key**
6. **SAVE NOW:**
   ```
   Access Key ID:     AKIA________________
   Secret Access Key: ________________________________________
   ```
7. Download CSV → Store securely

## Step 3.4: Enable MFA for IAM User

1. On user page → **"Assign MFA device"**
2. Same process as root

## Step 3.5: Sign Out, Sign In as IAM User

Use your console URL: `https://YOUR-ACCOUNT-ID.signin.aws.amazon.com/console`

---

# PART 4: Install Tools (Your Computer)

## Step 4.1: AWS CLI

**macOS:**
```bash
brew install awscli
```

**Windows:** Download https://awscli.amazonaws.com/AWSCLIV2.msi

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
```

## Step 4.2: Terraform

**macOS:**
```bash
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
```

**Windows:** Download from https://developer.hashicorp.com/terraform/downloads

**Linux:**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

## Step 4.3: Verify

```bash
aws --version        # ✓
terraform --version  # ✓
```

---

# PART 5: Configure AWS Credentials

Instead of saving credentials with `aws configure`, we'll use a `.env` file for better security and portability.

## Step 5.1: Create AWS Credentials File

```bash
cd ~/openclaw-infra
cat > .aws.env << 'EOF'
# AWS Credentials for Terraform
# Keep this file secure and never commit to git!

AWS_ACCESS_KEY_ID=AKIA________________
AWS_SECRET_ACCESS_KEY=________________________________________
AWS_DEFAULT_REGION=us-east-1
EOF
```

**Replace the placeholder values** with your actual access key and secret key from Step 3.3.

## Step 5.2: Secure the File

```bash
chmod 600 .aws.env
```

## Step 5.3: Load Credentials

```bash
source .aws.env
```

## Step 5.4: Verify

```bash
aws sts get-caller-identity
```

You should see your account ID and user ARN.

**Note**: You'll need to run `source .aws.env` each time you open a new terminal. Alternatively, add this to your shell profile:

```bash
# Add to ~/.bashrc or ~/.zshrc (optional)
echo "source ~/openclaw-infra/.aws.env" >> ~/.bashrc  # or ~/.zshrc for macOS
```

---

# PART 6: Get Your IP Address

```bash
curl ifconfig.me
```

**Write it down:** `___.___.___.___ `

---

# PART 7: Create Terraform Files

## Step 7.1: Clone the Repository

```bash
git clone https://github.com/qodex-ai/openclaw-worker.git
cd openclaw-worker
```

You should now have:
```
openclaw-worker/
├── main.tf                    # AWS infrastructure
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── user_data.sh              # EC2 bootstrap script
├── terraform.tfvars.example  # Configuration template
├── .gitignore                # Git ignore rules
├── .github/                  # CI/CD workflows
├── LICENSE                   # MIT License
├── README.md                 # Quick reference
└── SETUP_GUIDE.md           # This file
```

## Step 7.3: Create Your Config

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Fill in YOUR values:**

```hcl
aws_region    = "us-east-1"
instance_type = "t3.medium"

# YOUR IP - from step 6 (add /32 at end!)
my_ip_cidrs = ["203.0.113.50/32"]

# Your Anthropic API key
anthropic_api_key = "sk-ant-api03-xxxxxxxxxxxxx"
```

Save: `Ctrl+X`, `Y`, `Enter`

---

# PART 8: Deploy!

**Important**: Make sure your AWS credentials are loaded:

```bash
# Load AWS credentials (if not already done)
source .aws.env

# Verify credentials are loaded
aws sts get-caller-identity
```

## Step 8.1: Initialize Terraform

```bash
terraform init
```

## Step 8.2: Preview

```bash
terraform plan
```

Should show ~12 resources to create.

## Step 8.3: Deploy

```bash
terraform apply
```

Type **`yes`** when prompted. Wait 3-5 minutes.

## Step 8.4: Save Outputs

```bash
# Dashboard URL with token (save this!)
terraform output -raw dashboard_url_with_token

# SSH command
terraform output ssh_command

# All outputs
terraform output
```

---

# PART 9: Wait for Setup (~5-8 minutes)

The server is now bootstrapping automatically:
1. Installing Node.js 22 (required for OpenClaw)
2. Installing Docker (used internally by OpenClaw)
3. Installing OpenClaw via `npm install -g openclaw`
4. Starting OpenClaw as a systemd service

**Note**: Configure Slack integration through OpenClaw's dashboard after setup completes.

## Monitor Progress

```bash
# SSH in
$(terraform output -raw ssh_command)

# Watch bootstrap log
sudo tail -f /var/log/openclaw-bootstrap.log
```

Wait for:
```
==========================================
OpenClaw Bootstrap Complete: [timestamp]
==========================================
```

---

# PART 10: Verify Everything

## Step 10.1: Check Status

```bash
# On the server (via SSH)
oc status
```

Should show: `OpenClaw is running`

## Step 10.2: Open Dashboard

Get URL:
```bash
# On your local machine
terraform output -raw dashboard_url_with_token
```

Open in browser → You should see OpenClaw UI!

## Step 10.3: Configure Integrations

1. Open the OpenClaw dashboard
2. Configure Slack integration (if needed) through the UI
3. Add your AWS credentials for S3 backups (if needed)
4. Set up any other integrations you need

---

# PART 11: Daily Operations

## Quick Commands (on server)

| Command | What it does |
|---------|--------------|
| `oc status` | Check if running |
| `oc logs` | View logs |
| `oc restart` | Restart OpenClaw |
| `oc backup` | Manual backup to S3 (on-demand only) |
| `oc restore` | Restore from S3 |
| `oc update` | Update to latest version |
| `oc url` | Show dashboard URL |
| `oc token` | Show gateway token |

**Note**: Automated daily backups are disabled. Configure scheduled backups through OpenClaw's interface.

## From Your Computer

```bash
# Navigate to project directory
cd ~/openclaw-worker

# Load AWS credentials
source .aws.env

# SSH to server
$(terraform output -raw ssh_command)

# Get dashboard URL (in a new terminal)
cd ~/openclaw-worker
source .aws.env
terraform output -raw dashboard_url_with_token
```

## If Your IP Changes

```bash
cd ~/openclaw-worker
source .aws.env

# Edit config with new IP
nano terraform.tfvars

# Apply changes (instant, no restart needed)
terraform apply
```

## View S3 Backups

```bash
cd ~/openclaw-worker
source .aws.env
aws s3 ls s3://$(terraform output -raw s3_bucket)/backups/
```

---

# PART 12: Cleanup (If Needed)

```bash
cd ~/openclaw-worker
source .aws.env

# Download backups first (optional but recommended)
aws s3 sync s3://$(terraform output -raw s3_bucket) ./my-backups/

# Destroy all AWS resources
terraform destroy
# Type 'yes' when prompted

# Optionally remove local files
cd ~
rm -rf openclaw-worker
```

**Note**: This will delete the EC2 instance, S3 bucket (and all backups), and all related AWS resources. Make sure to download any data you need first!

---

# ✅ Done!

## What You Have Now

| Component | Details |
|-----------|---------|
| **EC2 Instance** | t3.medium (4GB RAM, Ubuntu 24.04) |
| **Installation** | OpenClaw via npm (Docker for internal use) |
| **Dashboard** | Web UI accessible via gateway token |
| **Security** | IP-restricted, encrypted S3 storage |
| **Backups** | Manual backup commands + S3 bucket available |
| **Cost** | ~$33/month (AWS) |

## Essential Commands

**On your local machine:**

```bash
# Always load credentials first
cd ~/openclaw-worker
source .aws.env

# Get dashboard URL
terraform output -raw dashboard_url_with_token

# SSH to server
$(terraform output -raw ssh_command)

# View backups
aws s3 ls s3://$(terraform output -raw s3_bucket)/backups/
```

**On the EC2 server (via SSH):**

```bash
oc status    # Check if OpenClaw is running
oc logs      # View live logs
oc restart   # Restart OpenClaw service
oc backup    # Create manual backup to S3 (no automated backups)
oc update    # Update OpenClaw to latest version
oc url       # Show dashboard URL with token
```

**Note**: Configure automated backups within OpenClaw using your AWS credentials.

## Quick Reference Card

Save this for future use:

```bash
# Local machine workflow
cd ~/openclaw-worker
source .aws.env
terraform output -raw dashboard_url_with_token  # Get URL
$(terraform output -raw ssh_command)            # SSH in

# Server management commands
oc status | logs | restart | backup | update | url
```

---

🦞 **Enjoy your private OpenClaw on AWS!**
