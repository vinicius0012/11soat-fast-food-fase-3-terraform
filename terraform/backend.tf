# Este arquivo deve ser executado PRIMEIRO para criar o backend
# Execute: terraform apply -target=aws_s3_bucket.terraform_state -target=aws_dynamodb_table.terraform_locks

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = "sa-east-1"
}

locals {
  name = "fastfood"
  tags = {
    Project = "fastfood"
    Stack   = "infra-app-aws"
    Owner   = "team"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ---------------- S3 Backend para Terraform State ----------------
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${local.name}-terraform-state-${random_id.bucket_suffix.hex}"
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------- DynamoDB para Terraform Locks ----------------
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "${local.name}-terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.tags
}

output "s3_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}
