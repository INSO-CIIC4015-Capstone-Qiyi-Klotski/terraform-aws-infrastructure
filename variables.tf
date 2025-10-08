#############################################
# File: variables.tf
# Purpose: Define global input variables for
# region, profile, project name, VPC, AZs, and
# subnet CIDRs for each tier (public, frontend,
# backend, DB).
#############################################

# ---------- AWS Provider ----------
variable "aws_region" {
  type    = string
  default = "us-east-2" # Ohio region
}

variable "aws_profile" {
  type    = string
  default = "default" # Override with your local AWS CLI profile
}

# ---------- Project metadata ----------
variable "project" {
  type    = string
  default = "three-tier-capstone"
}

# ---------- Networking: VPC & AZs ----------
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

# List of Availability Zones used for this deployment.
variable "azs" {
  type    = list(string)
  default = ["us-east-2a", "us-east-2b"]
}

# ---------- Networking: Subnet CIDRs ----------
# Public subnets (one per AZ)
variable "public_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/20", "10.0.16.0/20"]
}

# Private subnets for frontend tier (one per AZ)
variable "private_frontend_cidrs" {
  description = "CIDRs for private subnets in the FRONTEND tier (one per AZ, same order as var.azs)"
  type        = list(string)
  default     = ["10.0.128.0/20", "10.0.144.0/20"] # Original app tier CIDRs
}

# Private subnets for backend tier (one per AZ)
variable "private_backend_cidrs" {
  description = "CIDRs for private subnets in the BACKEND tier (one per AZ, same order as var.azs)"
  type        = list(string)
  default     = ["10.0.192.0/20", "10.0.208.0/20"] # Pick free ranges
}

# Private subnets for database tier (one per AZ)
variable "private_db_cidrs" {
  type    = list(string)
  default = ["10.0.160.0/20", "10.0.176.0/20"]
}

variable "db_password" {
  type      = string
  sensitive = true
}



# Bastion (jump host) --------------------------------------------
variable "enable_bastion" {
  description = "Create the bastion if true"
  type        = bool
  default     = true
}

variable "bastion_instance_type" {
  description = "Instance type for the bastion"
  type        = string
  default     = "t3.micro"
}

variable "bastion_subnet_id" {
  description = "PUBLIC subnet where to launch the bastion (optional). If empty, take the 1st public one."
  type        = string
  default     = ""
}

variable "bastion_allowed_cidr" {
  description = "Your IP/32 if you want to enable SSH (optional). If null, do not open 22/tcp."
  type        = string
  default     = null
}

variable "bastion_key_name" {
  description = "SSH key pair name (optional, only if you use port 22)"
  type        = string
  default     = null
}

variable "jwt_secret" {
  type = string
  sensitive = true
}