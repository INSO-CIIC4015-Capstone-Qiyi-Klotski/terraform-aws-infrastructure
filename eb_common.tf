#############################################
# File: eb_common.tf
# Purpose: Centralize Elastic Beanstalk
# platform selection (Docker on AL2023).
#
# Why this file?
# - Keeps the EB solution stack lookup in one place.
# - Other EB env files can reference this data source:
#     data.aws_elastic_beanstalk_solution_stack.docker_al2023.name
#
# Notes:
# - most_recent = true will select the latest matching platform
#   available in your AWS region. This helps keep environments
#   up to date but can also introduce drift over time.
# - If you need reproducible builds, consider pinning a specific
#   platform ARN/version instead of using a regex lookup
#   (example snippet included below).
#############################################

# Lookup the latest "64bit Amazon Linux 2023 running Docker" EB platform
data "aws_elastic_beanstalk_solution_stack" "docker_al2023" {
  most_recent = true
  name_regex  = "^64bit Amazon Linux 2023.*running Docker"
}

# -----------------------------------------
# Alternative: Pin a specific platform ARN
# (Uncomment and use in environments if you
# need strict reproducibility)
#
# data "aws_elastic_beanstalk_solution_stack" "docker_al2023_pinned" {
#   # Replace the name with the exact, full EB solution stack string you want
#   # e.g., "64bit Amazon Linux 2023 v4.2.0 running Docker"
#   most_recent = false
#   name_regex  = "^64bit Amazon Linux 2023 v4\\.2\\.0 running Docker$"
# }
#
# Then in your EB environments, reference:
#   solution_stack_name = data.aws_elastic_beanstalk_solution_stack.docker_al2023_pinned.name
# -----------------------------------------
