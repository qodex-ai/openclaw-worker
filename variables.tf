variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = <<-EOT
    EC2 instance type. t3.large is the target: 8GB RAM, unlimited CPU credits.
    t3.medium OOMs on the modern plugin set.
    The account's Standard-family vCPU quota can drop to 1 after months of idle,
    and every t3 size is 2 vCPU, so a first apply may be forced onto t2.small
    (1 vCPU, 2GB, plus the 2GB swap file this provisioning creates). It runs the
    gateway with an empty schedule. Raise the quota by support case, then resize.
  EOT
  type        = string
  default     = "t3.large"
}

variable "openclaw_version" {
  description = "OpenClaw npm version, pinned. Core and all three plugins install at this exact version."
  type        = string
  default     = "2026.9.2"
}

variable "node_min_version" {
  description = "Node floor asserted during bootstrap. OpenClaw 2026.9 needs 22.22.3 or newer."
  type        = string
  default     = "22.22.3"
}

variable "manage_dns" {
  description = "Create the Route53 A record for domain_name. Set false in a second workspace so two boxes never fight over the record."
  type        = bool
  default     = true
}

variable "my_ip_cidrs" {
  description = "Your IP addresses for access (format: [\"x.x.x.x/32\"])"
  type        = list(string)
}

variable "anthropic_api_key" {
  description = "Anthropic API key"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for HTTPS access (e.g., jarvis.example.com). Required for SSL certificate."
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the domain (optional - will be looked up if not provided)"
  type        = string
  default     = ""
}

variable "email" {
  description = "Email address for Let's Encrypt SSL certificate notifications"
  type        = string
}
