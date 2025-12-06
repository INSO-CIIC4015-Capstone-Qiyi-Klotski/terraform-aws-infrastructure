#############################################
# File: rds.tf
# Purpose: Provision a PostgreSQL RDS instance,
# generate a random password, and create a
# DB subnet group using private DB subnets.
#
# Notes:
# - Designed for dev/test usage (single-AZ,
#   deletion protection disabled, skip snapshot).
# - For production: enable multi-AZ, snapshots,
#   longer backup retention, and stricter deletion
#   protection.
#############################################

# ---------- Input variables ----------
# Database name and username.
variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

# ---------- DB Subnet Group ----------
# Ensures the RDS instance only runs in PRIVATE DB subnets.
resource "aws_db_subnet_group" "pg_subnets" {
  name       = "${var.project}-pg-subnets"
  subnet_ids = [for s in aws_subnet.private_db : s.id]
  tags = merge(local.common_tags, {
    Name = "${var.project}-pg-subnets"
  })
}

# ---------- Random password ----------
# Generate a strong random password.
# Note: the value is stored in Terraform state.
resource "random_password" "db_master" {
  length  = 20
  special = false
}

# ---------- RDS Instance ----------
# Creates a small PostgreSQL instance (Graviton-based).
resource "aws_db_instance" "postgres" {
  identifier = "${var.project}-pg"
  engine     = "postgres"
  # engine_version omitted to use AWS-recommended default

  instance_class    = "db.t4g.small" # Cost-efficient instance type
  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.pg_subnets.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  # ---- Availability & security ----
  multi_az            = false
  publicly_accessible = false

  # ---- Lifecycle settings (dev-friendly) ----
  deletion_protection     = false
  skip_final_snapshot     = true # For dev; enable snapshot in prod
  backup_retention_period = 1    # Minimal retention (prod: 7+)

  # ---- Maintenance settings ----
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(local.common_tags, {
    Name = "${var.project}-pg"
  })
}
