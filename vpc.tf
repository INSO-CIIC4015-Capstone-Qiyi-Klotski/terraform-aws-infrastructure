#############################################
# File: vpc.tf
# Purpose: Create a VPC with 2 public subnets
# and 6 private subnets (frontend, backend, db),
# plus per-AZ NAT gateways and properly scoped
# route tables/associations.
#############################################

# ---------- Local values ----------
# Common tags and AZ↔CIDR maps for each subnet tier.
locals {
  tags = {
    Project = var.project
    Stack   = "three-tier"
    Owner   = "janiel"
  }

  # Map AZ index → { az, cidr } for each tier
  pub_map = {
    for i, az in var.azs :
    i => { az = az, cidr = var.public_cidrs[i] }
  }

  frontend_map = {
    for i, az in var.azs :
    i => { az = az, cidr = var.private_frontend_cidrs[i] }
  }

  backend_map = {
    for i, az in var.azs :
    i => { az = az, cidr = var.private_backend_cidrs[i] }
  }

  db_map = {
    for i, az in var.azs :
    i => { az = az, cidr = var.private_db_cidrs[i] }
  }
}

# ---------- VPC & Internet Gateway ----------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.project}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = "${var.project}-igw" })
}

# ---------- Public subnets (2) ----------
resource "aws_subnet" "public" {
  for_each                = local.pub_map
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "${var.project}-public-${each.value.az}" })
}

# ---------- Private subnets: FRONTEND (2) ----------
resource "aws_subnet" "private_frontend" {
  for_each          = local.frontend_map
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = merge(local.tags, { Name = "${var.project}-private-frontend-${each.value.az}" })
}

# ---------- Private subnets: BACKEND (2) ----------
resource "aws_subnet" "private_backend" {
  for_each          = local.backend_map
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = merge(local.tags, { Name = "${var.project}-private-backend-${each.value.az}" })
}

# ---------- Private subnets: DB (2) ----------
resource "aws_subnet" "private_db" {
  for_each          = local.db_map
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = merge(local.tags, { Name = "${var.project}-private-db-${each.value.az}" })
}

# ---------- NAT per AZ (EIP + NAT in each public subnet) ----------
# One Elastic IP per public subnet (index keys match public subnets)
resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"
  tags     = merge(local.tags, { Name = "${var.project}-eip-nat-${each.key}" })
}

# One NAT gateway per AZ, placed in the corresponding public subnet
resource "aws_nat_gateway" "nat" {
  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id
  tags          = merge(local.tags, { Name = "${var.project}-nat-${each.key}" })
  # depends_on can help avoid ordering issues in some providers/regions:
  # depends_on = [aws_internet_gateway.igw]
}

# ---------- Public route table (shared by both public subnets) ----------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.tags, { Name = "${var.project}-rt-public" })
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---------- Private route tables (one per AZ) ----------
# Each private route table points its default route to the NAT of the same AZ.
resource "aws_route_table" "private" {
  for_each = aws_nat_gateway.nat
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }

  tags = merge(local.tags, { Name = "${var.project}-rt-private-${each.key}" })
}

# ---------- Route table associations (per tier, per AZ) ----------
# FRONTEND private subnets → private RT in their AZ
resource "aws_route_table_association" "private_frontend_assoc" {
  for_each       = aws_subnet.private_frontend
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# BACKEND private subnets → private RT in their AZ
resource "aws_route_table_association" "private_backend_assoc" {
  for_each       = aws_subnet.private_backend
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# DB private subnets → private RT in their AZ
resource "aws_route_table_association" "private_db_assoc" {
  for_each       = aws_subnet.private_db
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
