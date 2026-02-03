output "instance_public_ip" {
  description = "Public IP"
  value       = aws_eip.openclaw.public_ip
}

output "ssh_command" {
  description = "SSH command"
  value       = "ssh -i openclaw-key.pem ubuntu@${aws_eip.openclaw.public_ip}"
}

output "dashboard_url" {
  description = "Dashboard URL (no token)"
  value       = "http://${aws_eip.openclaw.public_ip}:18789"
}

output "dashboard_url_with_token" {
  description = "Dashboard URL with token"
  value       = "http://${aws_eip.openclaw.public_ip}:18789/?token=${random_password.gateway_token.result}"
  sensitive   = true
}

output "gateway_token" {
  description = "Gateway token"
  value       = random_password.gateway_token.result
  sensitive   = true
}

output "s3_bucket" {
  description = "S3 backup bucket"
  value       = aws_s3_bucket.backups.bucket
}

output "security_note" {
  value = <<-EOT
    
    ════════════════════════════════════════════════════════════════
    🔒 SECURITY: Access restricted to your IP only
       SSH:       ${join(", ", var.my_ip_cidrs)}
       Dashboard: ${join(", ", var.my_ip_cidrs)}
       Slack:     Works from anywhere (outbound only)
    ════════════════════════════════════════════════════════════════
    
    📋 QUICK COMMANDS (after SSH):
       oc status   - Check if running
       oc logs     - View logs
       oc restart  - Restart OpenClaw
       oc backup   - Manual backup to S3
       oc url      - Show dashboard URL with token
       oc update   - Update OpenClaw to latest version
    ════════════════════════════════════════════════════════════════
  EOT
}
