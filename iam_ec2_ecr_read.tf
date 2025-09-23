#############################################
# File: iam_ec2_ecr_read.tf
# Purpose: Attach IAM policy to EC2 instance
# role used by Elastic Beanstalk so that
# instances can pull Docker images from ECR.
#
# Notes:
# - Required if using private ECR repos for EB apps.
# - Without this, EB EC2 instances will fail to
#   pull images (ImagePullBackOff).
#############################################

# Attach the AWS-managed ECR read-only policy
# to the EC2 IAM role used by Elastic Beanstalk.
resource "aws_iam_role_policy_attachment" "ec2_ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
