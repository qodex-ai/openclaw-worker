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

variable "slack_bot_token" {
  description = "Slack Bot Token (xoxb-...)"
  type        = string
  sensitive   = true
}

variable "slack_app_token" {
  description = "Slack App Token (xapp-...)"
  type        = string
  sensitive   = true
}
