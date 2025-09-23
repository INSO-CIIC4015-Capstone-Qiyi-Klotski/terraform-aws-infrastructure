#############################################
# File: locals.tf
# Purpose: Define common local values to be
# reused across Terraform configuration,
# reducing duplication and ensuring consistent
# tagging of resources.
#############################################

locals {
  # Common tags applied to most resources.
  # Use local.common_tags in your resources:
  # tags = local.common_tags
  common_tags = {
    Project     = var.project # Project name from variables.tf
    Environment = "Dev"       # Change to "Prod" or "Staging" as needed
    Owner       = "janiel"    # Resource owner/maintainer
  }
}
