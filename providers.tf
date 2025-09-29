#############################################
# File: providers.tf
# Purpose: Pin Terraform/core provider versions
# and configure the AWS provider with region,
# profile, and default resource tags.
#############################################

terraform {
  # Require a recent Terraform version for stability/features.
  required_version = ">= 1.6.0"

  # Provider constraints to avoid unexpected upgrades.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# AWS provider configuration.
# Notes:
# - 'profile' is convenient for local use (shared credentials).
# - In CI/CD, prefer environment variables (AWS_ACCESS_KEY_ID, etc.)
#   and remove/override 'profile' to avoid coupling to local config.
# - 'default_tags' applies to all taggable resources automatically.
provider "aws" {
  region = var.aws_region

  # Organization-wide default tags (merged with resource-level tags).
  default_tags {
    tags = {
      Project     = var.project # From variables.tf
      Environment = "Dev"       # Change to "Prod"/"Staging" per workspace/env
      Owner       = "janiel"
    }
  }
}
