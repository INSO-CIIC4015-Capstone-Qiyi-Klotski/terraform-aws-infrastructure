#############################################
# File: sg.tf
# Purpose: Define all security groups required
# for the frontend ALB, backend ALB, app
# instances, and database. Enforces least
# privilege by limiting ingress rules.
#############################################

# ---------- Local ports ----------
locals {
  alb_port_http  = 80
  alb_port_https = 443
  app_port       = 80
  db_port        = 5432
}

# ---------- Security Group: Frontend ALB ----------
resource "aws_security_group" "fe_alb_sg" {
  name        = "${var.project}-fe-alb-sg"
  description = "Allow HTTP/HTTPS from Internet to FE ALB"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP/HTTPS inbound from anywhere
  ingress {
    from_port   = local.alb_port_http
    to_port     = local.alb_port_http
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = local.alb_port_https
    to_port     = local.alb_port_https
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project}-fe-alb-sg" })
}

# ---------- Security Group: Backend ALB ----------
resource "aws_security_group" "be_alb_sg" {
  name        = "${var.project}-be-alb-sg"
  description = "Allow HTTP/HTTPS from Internet to BE ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = local.alb_port_http
    to_port     = local.alb_port_http
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = local.alb_port_https
    to_port     = local.alb_port_https
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project}-be-alb-sg" })
}

# ---------- Security Group: Frontend App Instances ----------
resource "aws_security_group" "fe_app_sg" {
  name        = "${var.project}-fe-app-sg"
  description = "Allow traffic from FE ALB to FE App"
  vpc_id      = aws_vpc.main.id

  # Allow inbound traffic ONLY from FE ALB
  ingress {
    description     = "App port from FE ALB"
    from_port       = local.app_port
    to_port         = local.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.fe_alb_sg.id]
  }

  # Full outbound access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project}-fe-app-sg" })
}

# ---------- Security Group: Backend App Instances ----------
resource "aws_security_group" "be_app_sg" {
  name        = "${var.project}-be-app-sg"
  description = "Allow traffic from BE ALB to BE App"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from BE ALB"
    from_port       = local.app_port
    to_port         = local.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.be_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project}-be-app-sg" })
}

# ---------- Security Group: Database ----------
resource "aws_security_group" "db_sg" {
  name        = "${var.project}-db-sg"
  description = "Allow Postgres from BE App only"
  vpc_id      = aws_vpc.main.id

  # Allow Postgres traffic only from Backend App SG
  ingress {
    description     = "Postgres from BE App"
    from_port       = local.db_port
    to_port         = local.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.be_app_sg.id]
  }

  # Allow outbound traffic (e.g. for RDS updates, logging)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project}-db-sg" })
}
