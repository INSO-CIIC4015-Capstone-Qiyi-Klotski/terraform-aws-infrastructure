#############################################
# File: eb_frontend.tf
# Purpose: Elastic Beanstalk application and
# environment for the Frontend (Next.js) app.
#
# Notes:
# - LoadBalanced environment with ALB in public subnets.
# - EC2 instances run in PRIVATE frontend subnets (no public IP).
# - Security: FE ALB SG → FE App SG; no direct public access to EC2.
# - TLS: ALB HTTPS(443) uses ACM certificate validated via DNS.
#############################################

# -----------------------------
# Elastic Beanstalk Application
# -----------------------------
resource "aws_elastic_beanstalk_application" "fe_app" {
  name        = "${var.project}-fe-app"
  description = "Frontend (Next.js) - EB app"
}

# --------------------------------
# Elastic Beanstalk Environment
# --------------------------------
resource "aws_elastic_beanstalk_environment" "fe_env" {
  name                = "${var.project}-fe-env"
  application         = aws_elastic_beanstalk_application.fe_app.name
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.docker_al2023.name
  # Uses the latest "64bit Amazon Linux 2023 running Docker" solution stack.

  # -------- Environment type (ALB) --------
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced" # ALB in front of instances
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application" # Use ALB
  }

  # -------- VPC, Subnets & SGs --------
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.main.id
  }

  # EC2 instances live in PRIVATE frontend subnets (both AZs).
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", [for _, s in aws_subnet.private_frontend : s.id])
  }

  # ALB lives in PUBLIC subnets (Internet-facing).
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", [for _, s in aws_subnet.public : s.id])
  }

  # Prevent public IPs on instances.
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "false"
  }

  # -------- Launch configuration --------
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.ec2_profile.name
  }

  # FE App SG (only allows traffic from FE ALB SG).
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.fe_app_sg.id
  }

  # FE ALB SG (ingress 80/443 from Internet).
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "SecurityGroups"
    value     = aws_security_group.fe_alb_sg.id
  }


  # -------- Capacity (Auto Scaling) --------
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "2"
  }

  # -------- ALB HTTPS Listener (443) --------
  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "ListenerEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "Protocol"
    value     = "HTTPS"
  }

  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "SSLCertificateArns"
    value     = aws_acm_certificate_validation.site.certificate_arn
  }

  # -------- Process configuration --------
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "Port"
    value     = "80"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "Protocol"
    value     = "HTTP"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckPath"
    value     = "/"
  }

  # -------- Root volume configuration --------
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeType"
    value     = "gp3"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeSize"
    value     = "40" # Adjust if needed
  }

  # -------- Deployment strategy --------
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "Immutable"
  }

  # -------- Auto Scaling (CPU-based triggers) --------
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "Cooldown"
    value     = "300"
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "MeasureName"
    value     = "CPUUtilization"
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Statistic"
    value     = "Average"
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Unit"
    value     = "Percent"
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Period"
    value     = "60"
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "BreachDuration"
    value     = "180"
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "UpperThreshold"
    value     = "70"
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "LowerThreshold"
    value     = "30"
  }

  # -------- Health reporting --------
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  # -------- CloudWatch Logs streaming --------
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = "14"
  }
}
