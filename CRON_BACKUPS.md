# Automated Daily Backups with Cron

This document explains the automated backup system configured during OpenClaw deployment.

## Overview

OpenClaw is automatically configured with daily S3 backups using cron. Backups run at **2 AM UTC** every day.

## How It Works

### Cron Configuration

During deployment, the `user_data.sh` script automatically sets up a cron job for the `ubuntu` user:

```cron
# Automated daily backup to S3 at 2 AM UTC
0 2 * * * bash -l -c '/home/ubuntu/bin/oc backup >> /home/ubuntu/.openclaw/backup.log 2>&1'
```

**Schedule breakdown:**
- `0 2 * * *` = Every day at 2:00 AM UTC
- Runs the `oc backup` command
- Logs output to `~/.openclaw/backup.log`

### Backup Process

1. **Cron triggers** at 2 AM UTC
2. **oc backup script** runs:
   - Creates tar.gz archive of `~/.openclaw` and `~/.env`
   - Uploads to S3 bucket with timestamp
   - Logs success/failure
3. **S3 lifecycle** auto-deletes backups after 180 days

## Managing Automated Backups

### View Backup Schedule

```bash
# SSH to server
$(terraform output -raw ssh_command)

# View crontab
crontab -l
```

### View Backup Logs

```bash
# SSH to server
ssh -i openclaw-key.pem ubuntu@<your-ip>

# View recent backups (last 20 lines)
tail -20 ~/.openclaw/backup.log

# Follow logs in real-time
tail -f ~/.openclaw/backup.log

# View all logs
cat ~/.openclaw/backup.log
```

### List S3 Backups

```bash
# From local machine
aws s3 ls s3://$(terraform output -raw s3_bucket)/backups/ --human-readable

# From server
oc restore  # Shows available backups
```

### Change Backup Time

To run backups at a different time:

```bash
# SSH to server
$(terraform output -raw ssh_command)

# Edit crontab
crontab -e

# Change the time (example: 3:30 AM UTC)
30 3 * * * bash -l -c '/home/ubuntu/bin/oc backup >> /home/ubuntu/.openclaw/backup.log 2>&1'
```

**Common times:**
- `0 1 * * *` = 1:00 AM UTC
- `0 2 * * *` = 2:00 AM UTC (default)
- `0 3 * * *` = 3:00 AM UTC
- `30 4 * * *` = 4:30 AM UTC

### Change Backup Frequency

**Weekly backups** (Sundays at 2 AM):
```cron
0 2 * * 0 bash -l -c '/home/ubuntu/bin/oc backup >> /home/ubuntu/.openclaw/backup.log 2>&1'
```

**Twice daily** (2 AM and 2 PM):
```cron
0 2,14 * * * bash -l -c '/home/ubuntu/bin/oc backup >> /home/ubuntu/.openclaw/backup.log 2>&1'
```

**Every 6 hours**:
```cron
0 */6 * * * bash -l -c '/home/ubuntu/bin/oc backup >> /home/ubuntu/.openclaw/backup.log 2>&1'
```

### Disable Automated Backups

To stop automated backups:

```bash
# SSH to server
$(terraform output -raw ssh_command)

# Remove backup cron job
crontab -l | grep -v "oc backup" | crontab -

# Verify it's removed
crontab -l
```

### Re-enable Automated Backups

```bash
# SSH to server
$(terraform output -raw ssh_command)

# Add back the cron job
(crontab -l 2>/dev/null; echo "0 2 * * * bash -l -c '/home/ubuntu/bin/oc backup >> /home/ubuntu/.openclaw/backup.log 2>&1'") | crontab -
```

## Troubleshooting

### Check if cron is running

```bash
sudo systemctl status cron
```

### Test backup manually

```bash
# SSH to server
$(terraform output -raw ssh_command)

# Run backup manually
oc backup

# Check if it appears in S3
aws s3 ls s3://$(terraform output -raw s3_bucket)/backups/
```

### Backups not running

1. **Check crontab:**
   ```bash
   crontab -l
   ```

2. **Check cron logs:**
   ```bash
   sudo grep CRON /var/log/syslog | tail -20
   ```

3. **Check backup log:**
   ```bash
   tail -50 ~/.openclaw/backup.log
   ```

4. **Test IAM permissions:**
   ```bash
   aws s3 ls s3://$(terraform output -raw s3_bucket)/
   ```

### Verify next backup time

```bash
# SSH to server
$(terraform output -raw ssh_command)

# Show cron schedule
crontab -l

# Current time
date -u

# Calculate next run
echo "Next backup: Tomorrow at 2:00 AM UTC"
```

## Backup Details

### What's Backed Up

- OpenClaw configuration (`~/.openclaw/openclaw.json`)
- Workspace data (IDENTITY, MEMORY, AGENTS)
- Device credentials and pairing info
- Agent sessions
- Environment variables (`~/.env`)
- Cron jobs configuration

### Backup Size

Typical backup: **~80-100 KB** (compressed)

### Retention Policy

- **Storage:** S3 bucket with AES-256 encryption
- **Lifecycle:** Auto-deleted after 180 days
- **Access:** Private (IAM role only)

### Backup Naming

Format: `openclaw-backup-YYYYMMDD-HHMMSS.tar.gz`

Example: `openclaw-backup-20260204-121442.tar.gz`

## Restoration

### Restore from automated backup

```bash
# SSH to server
$(terraform output -raw ssh_command)

# List available backups
oc restore

# Restore specific backup
oc restore openclaw-backup-20260204-121442.tar.gz
```

### Download backup locally

```bash
# From local machine
aws s3 cp s3://$(terraform output -raw s3_bucket)/backups/openclaw-backup-20260204-121442.tar.gz ./

# Extract locally
tar -xzvf openclaw-backup-20260204-121442.tar.gz
```

## Cost

Automated daily backups cost approximately:
- **Storage:** ~$0.001/month (100 KB × 180 backups ≈ 18 MB)
- **PUT requests:** ~$0.001/month (30 uploads)
- **Total:** ~$0.002/month (negligible)

## Best Practices

1. ✅ **Keep automated backups enabled** - They're free and automatic
2. ✅ **Monitor backup logs weekly** - Ensure backups are succeeding
3. ✅ **Test restoration quarterly** - Verify backups are valid
4. ✅ **Download critical backups** - Store important backups locally
5. ✅ **Adjust schedule for your timezone** - Consider your peak usage times

## Additional Manual Backups

Automated backups don't replace manual backups before major changes:

```bash
# Before updates
$(terraform output -raw ssh_command)
oc backup

# Before configuration changes
oc backup

# Before system upgrades
oc backup
```

---

**Last Updated:** February 4, 2026
**Status:** ✅ Automated backups enabled and verified
