#############################################
# File: iam_ec2.tf
# Purpose: Create IAM role and instance profile
# for EC2 instances used by Elastic Beanstalk.
#
# Notes:
# - Grants permissions for SSM (Session Manager),
#   S3 read-only access (e.g., to fetch artifacts),
#   EB web tier operations, CloudWatch metrics/logs,
#   and ECR image pulls.
# - This role is referenced by aws_iam_instance_profile.ec2_profile,
#   which is then used in eb_backend.tf and eb_frontend.tf.
#############################################

# ---------- IAM Assume Role Policy ----------
# Allow EC2 service to assume this role.
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ---------- IAM Role for EC2 Instances ----------
resource "aws_iam_role" "ec2_role" {
  name               = "${var.project}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# ---------- Attach Managed Policies ----------
# 1. Allow SSM Session Manager connectivity
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 2. Allow EC2 instances to read from S3 (read-only)
resource "aws_iam_role_policy_attachment" "s3_ro" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# 3. Grant EB Web Tier permissions (logs, health, etc.)
resource "aws_iam_role_policy_attachment" "eb_web_tier" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

# 4. Allow CloudWatch agent to push metrics/logs
resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# 5. Allow pulling images from ECR (read-only)
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ---------- Instance Profile ----------
# Required by Elastic Beanstalk to attach the IAM role to EC2 instances.
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
