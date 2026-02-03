# 🦞 OpenClaw on AWS — Complete Setup Guide

> **Time**: ~45 minutes  
> **Cost**: ~$33/month (t3.medium)  
> **Channel**: Slack  
> **Install**: npm package (cleaner than git clone)

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
│                          ├── Slack Integration ◄──── Slack API   │
│                          └── Daily backups ──────► S3 Bucket    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 What You Need

- ✅ Slack Bot Token (`xoxb-...`)
- ✅ Slack App Token (`xapp-...`)  
- ✅ Anthropic API key (`sk-ant-...`)

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

# PART 5: Configure AWS CLI

```bash
aws configure
```

Enter:
```
AWS Access Key ID:     AKIA________________
AWS Secret Access Key: ________________________________________
Default region name:   us-east-1
Default output format: json
```

Verify:
```bash
aws sts get-caller-identity
```

---

# PART 6: Get Your IP Address

```bash
curl ifconfig.me
```

**Write it down:** `___.___.___.___ `

---

# PART 7: Create Terraform Files

## Step 7.1: Create Directory

```bash
mkdir -p ~/openclaw-infra
cd ~/openclaw-infra
```

## Step 7.2: Download & Extract Files

Extract the `openclaw-terraform.zip` to `~/openclaw-infra/`

You should have:
```
~/openclaw-infra/
├── main.tf
├── variables.tf
├── outputs.tf
├── user_data.sh
├── terraform.tfvars.example
└── .gitignore
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

# Your Slack tokens (you already have these)
slack_bot_token = "xoxb-1234567890-xxxxxxxxxxxxx"
slack_app_token = "xapp-1-A0123456789-xxxxxxxxxxxxx"
```

Save: `Ctrl+X`, `Y`, `Enter`

---

# PART 8: Deploy!

## Step 8.1: Initialize

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

The server is now:
1. Installing Node.js 22
2. Installing Docker
3. Installing OpenClaw via npm
4. Configuring Slack
5. Starting the gateway

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

## Step 10.3: Test Slack

1. Open Slack
2. DM your bot or @mention in a channel
3. Should get a response!

---

# PART 11: Daily Operations

## Quick Commands (on server)

| Command | What it does |
|---------|--------------|
| `oc status` | Check if running |
| `oc logs` | View logs |
| `oc restart` | Restart OpenClaw |
| `oc backup` | Manual backup to S3 |
| `oc restore` | Restore from S3 |
| `oc update` | Update to latest version |
| `oc url` | Show dashboard URL |
| `oc token` | Show gateway token |

## From Your Computer

```bash
# SSH to server
cd ~/openclaw-infra
$(terraform output -raw ssh_command)

# Get dashboard URL
terraform output -raw dashboard_url_with_token
```

## If Your IP Changes

```bash
# Edit config with new IP
nano ~/openclaw-infra/terraform.tfvars

# Apply changes (instant)
terraform apply
```

## View S3 Backups

```bash
aws s3 ls s3://$(terraform output -raw s3_bucket)/backups/
```

---

# PART 12: Cleanup (If Needed)

```bash
cd ~/openclaw-infra

# Download backups first
aws s3 sync s3://$(terraform output -raw s3_bucket) ./my-backups/

# Destroy everything
terraform destroy
# Type 'yes'
```

---

# ✅ Done!

## What You Have

| Component | Details |
|-----------|---------|
| EC2 | t3.medium (4GB RAM) |
| Install | npm package (easy updates) |
| Channel | Slack connected |
| Security | Your IP only |
| Backups | Daily to S3 |
| Cost | ~$33/month |

## Key URLs & Commands

```bash
# Dashboard
terraform output -raw dashboard_url_with_token

# SSH
$(terraform output -raw ssh_command)

# On server
oc status    # Check status
oc logs      # View logs
oc backup    # Backup now
oc update    # Update OpenClaw
```

---

🦞 **Enjoy your private OpenClaw on AWS!**
