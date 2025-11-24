#############################################
# File: eb_backend.tf
# Purpose: Elastic Beanstalk application and
# environment for the Backend API (Docker on
# Amazon Linux 2023), behind an ALB.
#
# Notes:
# - Environment is LoadBalanced with ALB in public subnets.
# - EC2 instances run in PRIVATE backend subnets (no public IP).
# - Security: BE ALB SG → BE App SG; DB allows only from BE App SG.
# - TLS: ALB HTTPS(443) uses an ACM certificate validated via DNS.
#############################################

# -----------------------------
# Elastic Beanstalk Application
# -----------------------------
resource "aws_elastic_beanstalk_application" "be_app" {
  name        = "${var.project}-be-app"
  description = "Backend API - EB app"
}

# --------------------------------
# Elastic Beanstalk Environment
# --------------------------------
resource "aws_elastic_beanstalk_environment" "be_env" {
  name                = "${var.project}-be-env"
  application         = aws_elastic_beanstalk_application.be_app.name
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.docker_al2023.name
  # Tip: keep solution stack in a data source (eb_common.tf) to always pull latest AL2023 Docker.

  # -------- Environment type (ALB) --------
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced" # ALB in front of instances
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application" # Use ALB (not Classic/Network)
  }

  # -------- VPC, Subnets & SGs --------
  # VPC where EB will deploy networking resources.
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.main.id
  }

  # EC2 instances should live in PRIVATE backend subnets (both AZs).
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", [for _, s in aws_subnet.private_backend : s.id])
  }

  # ALB must live in PUBLIC subnets (both AZs) to be Internet-facing.
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", [for _, s in aws_subnet.public : s.id])
  }

  # Do NOT assign public IPs to instances (they will egress via NAT).
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "false"
  }

  # -------- Launch configuration (instances) --------
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro" # Adjust per workload/cost
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.ec2_profile.name
  }

  # Attach BE App security group to instances (traffic only from BE ALB).
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.be_app_sg.id
  }

  # -------- ALB security group (ingress 80/443 from Internet) --------
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "SecurityGroups"
    value     = aws_security_group.be_alb_sg.id
  }

  # -------- Application environment variables --------
  # Expose container port (your container must listen on $PORT).
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PORT"
    value     = "80"
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

  # -------- Database connection (passed as env vars) --------
  # Avoid hardcoding secrets in code; rotate via Terraform or SSM if needed.
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_HOST"
    value     = aws_db_instance.postgres.address
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_PORT"
    value     = "5432"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_NAME"
    value     = var.db_name
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_USER"
    value     = var.db_username
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "DB_PASSWORD"
    value     = var.db_password
  }

  setting {
  namespace = "aws:elasticbeanstalk:application:environment"
  name      = "JWT_SECRET"
  value     = var.jwt_secret
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "AWS_REGION"
    value     = var.aws_region
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "SES_SENDER_EMAIL"
    value     = var.ses_sender_email
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PUBLIC_BASE_URL"
    value     = var.public_base_url
  }

  # -------- ALB HTTPS Listener (443) --------
  # Use the validated ACM certificate ARN (DNS validated via dnd_tls.tf).
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

  # -------- Process configuration (AL2023, no proxy by default) --------
  # Define process/healthcheck to configure Target Group behavior.
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
    value     = "40" # Adjust as needed
  }

  # -------- Deployment strategy --------
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "Immutable" # Safer deploys; consider Rolling for faster
  }

  # -------- Auto Scaling policies (CPU-based) --------
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

  # -------- Enhanced health reporting --------
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
