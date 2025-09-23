#############################################
# File: ecr.tf
# Purpose: Create Amazon ECR repositories for
# frontend and backend Docker images, with
# encryption, scanning, and lifecycle policies.
#############################################

# ---------- Local values ----------
# Define repository names based on project variable.
locals {
  ecr_fe_name = "${var.project}-fe"
  ecr_be_name = "${var.project}-be"
}

# ---------- ECR Repository: Frontend ----------
resource "aws_ecr_repository" "fe" {
  name                 = local.ecr_fe_name
  image_tag_mutability = "MUTABLE"                        # Allow overwriting tags (use carefully in CI/CD)
  force_delete         = true                             # Allows repo deletion even if images exist
  image_scanning_configuration { scan_on_push = true }    # Enable vulnerability scans on push
  encryption_configuration { encryption_type = "AES256" } # Server-side encryption
  tags = merge(local.common_tags, {
    Component = "frontend"
  })
}

# ---------- ECR Repository: Backend ----------
resource "aws_ecr_repository" "be" {
  name                 = local.ecr_be_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  tags = merge(local.common_tags, {
    Component = "backend"
  })
}

# ---------- Lifecycle Policy: Keep Last 10 Images ----------
# Helps save storage costs by keeping only the last 10 pushed images.
resource "aws_ecr_lifecycle_policy" "fe" {
  repository = aws_ecr_repository.fe.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Apply the same lifecycle policy to the backend repository
resource "aws_ecr_lifecycle_policy" "be" {
  repository = aws_ecr_repository.be.name
  policy     = aws_ecr_lifecycle_policy.fe.policy
}
