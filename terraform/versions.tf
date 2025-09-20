terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
  # backend "s3" {
  #   bucket         = "SEU-BUCKET-REMOTE-STATE"
  #   key            = "infra-app-aws/terraform.tfstate"
  #   region         = "sa-east-1"
  #   dynamodb_table = "SEU-DDB-LOCK"
  #   encrypt        = true
  # }
}
provider "aws" {
  region = var.aws_region
}
