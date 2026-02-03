terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = "OpenClaw"
      ManagedBy = "Terraform"
    }
  }
}

# Get latest Ubuntu 24.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_vpc" "default" { default = true }
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Random suffix for unique names
resource "random_id" "suffix" {
  byte_length = 4
}

# Secure gateway token
resource "random_password" "gateway_token" {
  length  = 48
  special = false
}

# Security Group - YOUR IP ONLY
resource "aws_security_group" "openclaw" {
  name        = "openclaw-sg-${random_id.suffix.hex}"
  description = "OpenClaw - Restricted to owner IP"
  vpc_id      = data.aws_vpc.default.id

  # SSH - Your IP only
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.my_ip_cidrs
  }

  # OpenClaw Dashboard - Your IP only
  ingress {
    description = "OpenClaw Gateway from my IP"
    from_port   = 18789
    to_port     = 18789
    protocol    = "tcp"
    cidr_blocks = var.my_ip_cidrs
  }

  # All outbound (needed for Slack, AI APIs, etc.)
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "openclaw-sg" }
}

# Generate SSH key
resource "tls_private_key" "openclaw" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "openclaw" {
  key_name   = "openclaw-key-${random_id.suffix.hex}"
  public_key = tls_private_key.openclaw.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.openclaw.private_key_pem
  filename        = "${path.module}/openclaw-key.pem"
  file_permission = "0400"
}

# S3 Bucket for backups
resource "aws_s3_bucket" "backups" {
  bucket = "openclaw-backups-${data.aws_caller_identity.current.account_id}-${random_id.suffix.hex}"
  tags   = { Name = "openclaw-backups" }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    id     = "cleanup"
    status = "Enabled"
    filter { prefix = "backups/" }
    expiration { days = 180 }
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
}

# IAM Role for EC2
resource "aws_iam_role" "openclaw" {
  name = "openclaw-ec2-role-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "s3_access" {
  name = "openclaw-s3-access"
  role = aws_iam_role.openclaw.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject", "s3:GetObject", "s3:DeleteObject",
        "s3:ListBucket", "s3:GetBucketLocation"
      ]
      Resource = [
        aws_s3_bucket.backups.arn,
        "${aws_s3_bucket.backups.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.openclaw.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "openclaw" {
  name = "openclaw-profile-${random_id.suffix.hex}"
  role = aws_iam_role.openclaw.name
}

# EC2 Instance
resource "aws_instance" "openclaw" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.openclaw.key_name
  iam_instance_profile   = aws_iam_instance_profile.openclaw.name
  vpc_security_group_ids = [aws_security_group.openclaw.id]
  subnet_id              = data.aws_subnets.default.ids[0]

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    gateway_token     = random_password.gateway_token.result
    s3_bucket         = aws_s3_bucket.backups.bucket
    aws_region        = var.aws_region
    anthropic_api_key = var.anthropic_api_key
  }))

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  tags = { Name = "openclaw-server" }

  lifecycle { ignore_changes = [ami] }
}

# Elastic IP
resource "aws_eip" "openclaw" {
  instance = aws_instance.openclaw.id
  domain   = "vpc"
  tags     = { Name = "openclaw-eip" }
}
