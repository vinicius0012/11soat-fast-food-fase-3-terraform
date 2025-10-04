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
  # backend "s3" {
  #   bucket         = "fastfood-terraform-state-XXXXX"
  #   key            = "infra-app-aws/terraform.tfstate"
  #   region         = "sa-east-1"
  #   dynamodb_table = "fastfood-terraform-locks"
  #   encrypt        = true
  # }
}
provider "aws" {
  region = var.aws_region
}
