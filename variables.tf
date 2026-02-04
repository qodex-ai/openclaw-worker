variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
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
