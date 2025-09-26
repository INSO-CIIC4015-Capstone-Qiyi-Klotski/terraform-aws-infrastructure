#############################################
# File: outputs.tf
# Purpose: Centralize Terraform outputs for
# networking (VPC, subnets, NAT), Elastic
# Beanstalk (apps/envs), ECR repos, RDS DB,
# security groups, and artifacts buckets.
#
# Notes:
# - These outputs are useful for debugging,
#   CI/CD pipelines, or other Terraform stacks
#   that consume these values via remote state.
#############################################

# ---------- Networking ----------
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_frontend_subnets" {
  value = { for k, s in aws_subnet.private_frontend : k => s.id }
}

output "private_backend_subnets" {
  value = { for k, s in aws_subnet.private_backend : k => s.id }
}

output "private_db_subnets" {
  value = [for s in aws_subnet.private_db : s.id]
}

output "nat_public_ip" {
  value = { for k, e in aws_eip.nat : k => e.public_ip }
}

# ---------- Elastic Beanstalk ----------
output "be_app_name" {
  value = aws_elastic_beanstalk_application.be_app.name
}

output "be_env_name" {
  value = aws_elastic_beanstalk_environment.be_env.name
}

output "fe_app_name" {
  value = aws_elastic_beanstalk_application.fe_app.name
}

output "fe_env_name" {
  value = aws_elastic_beanstalk_environment.fe_env.name
}

# ---------- ECR Repositories ----------
output "ecr_fe_repo_url" {
  value = aws_ecr_repository.fe.repository_url
}

output "ecr_be_repo_url" {
  value = aws_ecr_repository.be.repository_url
}

# ---------- Database ----------
output "db_endpoint" {
  value = aws_db_instance.postgres.address
}

output "db_port" {
  value = aws_db_instance.postgres.port
}

output "db_name" {
  value = var.db_name
}

output "db_username" {
  value = var.db_username
}
# NOTE: The password is intentionally not output
# for security reasons (it remains in Terraform state).

# ---------- S3 Buckets for Artifacts ----------
output "fe_artifacts_bucket" {
  value = aws_s3_bucket.fe_artifacts.bucket
}

output "be_artifacts_bucket" {
  value = aws_s3_bucket.be_artifacts.bucket
}

# ---------- Security Groups ----------
output "sg_db_id" {
  value = aws_security_group.db_sg.id
}


# ---------- Bastion ----------
output "bastion_instance_id" {
  value = try(aws_instance.bastion[0].id, null)
}

output "bastion_public_ip" {
  value = try(aws_instance.bastion[0].public_ip, null)
}