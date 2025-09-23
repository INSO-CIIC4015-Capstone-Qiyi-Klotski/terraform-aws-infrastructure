#############################################
# File: s3_artifacts.tf
# Purpose: Provision S3 buckets for storing
# frontend and backend build artifacts.
#
# Notes:
# - Buckets are uniquely named per account + region.
# - Versioning enabled to keep track of artifact history.
# - Public access is fully blocked for security.
#############################################

# ---------- Caller identity ----------
# Used to include AWS account ID in bucket names to ensure uniqueness.
data "aws_caller_identity" "me" {}

# ---------- Local bucket names ----------
locals {
  fe_bucket = "${var.project}-fe-artifacts-${data.aws_caller_identity.me.account_id}-${var.aws_region}"
  be_bucket = "${var.project}-be-artifacts-${data.aws_caller_identity.me.account_id}-${var.aws_region}"
}

# ---------- Frontend artifacts bucket ----------
resource "aws_s3_bucket" "fe_artifacts" {
  bucket        = local.fe_bucket
  force_destroy = true # Allow deletion even if objects exist
  tags = merge(local.common_tags, {
    Component = "frontend"
  })
}

# Enable versioning to keep old artifact versions.
resource "aws_s3_bucket_versioning" "fe" {
  bucket = aws_s3_bucket.fe_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block all forms of public access for security.
resource "aws_s3_bucket_public_access_block" "fe" {
  bucket                  = aws_s3_bucket.fe_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------- Backend artifacts bucket ----------
resource "aws_s3_bucket" "be_artifacts" {
  bucket        = local.be_bucket
  force_destroy = true
  tags = merge(local.common_tags, {
    Component = "backend"
  })
}

# Enable versioning for backend bucket.
resource "aws_s3_bucket_versioning" "be" {
  bucket = aws_s3_bucket.be_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block all forms of public access for backend bucket as well.
resource "aws_s3_bucket_public_access_block" "be" {
  bucket                  = aws_s3_bucket.be_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
