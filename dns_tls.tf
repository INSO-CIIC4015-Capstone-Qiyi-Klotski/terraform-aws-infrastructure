#############################################
# File: dnd_tls.tf
# Purpose: Configure DNS, ACM TLS certificate,
# and Route 53 records for frontend (www) and
# backend (api) environments in Elastic Beanstalk.
#############################################

# ---------- Input Variables ----------
# Root domain for which DNS records and certificate will be created.
# Example: "example.com"
variable "domain_name" {
  type = string
  # default = "example.com" # Optionally set in a tfvars file
}

# ---------- Route 53 Hosted Zone ----------
# Looks up the PUBLIC hosted zone for the specified domain in Route 53.
# This must already exist (purchased or imported).
data "aws_route53_zone" "primary" {
  name         = var.domain_name
  private_zone = false
}

# ---------- Local Values ----------
# Define subdomains for frontend and backend.
locals {
  fe_host = "www.${var.domain_name}" # Frontend on www
  be_host = "api.${var.domain_name}" # Backend on api
}

# ---------- ACM Certificate ----------
# Requests an ACM certificate with DNS validation for:
# - Root domain
# - www.<domain> (frontend)
# - api.<domain> (backend)
# Certificate must be created in the same region as the ALB / Elastic Beanstalk environments.
resource "aws_acm_certificate" "site" {
  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = [local.fe_host, local.be_host]

  lifecycle {
    create_before_destroy = true # Prevent downtime when replacing certificate
  }
}

# ---------- DNS Validation Records ----------
# Automatically creates the CNAME records required for ACM DNS validation.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

# Validates the certificate once the CNAME records are propagated.
resource "aws_acm_certificate_validation" "site" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ---------- DNS Records for Elastic Beanstalk ----------
# Creates CNAME records pointing to the EB environment's CNAME.
# This gives you pretty URLs:
# - www.<domain> → frontend EB environment
# - api.<domain> → backend EB environment
resource "aws_route53_record" "fe_cname" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.fe_host
  type    = "CNAME"
  ttl     = 60
  records = [aws_elastic_beanstalk_environment.fe_env.cname]
}

resource "aws_route53_record" "be_cname" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.be_host
  type    = "CNAME"
  ttl     = 60
  records = [aws_elastic_beanstalk_environment.be_env.cname]
}
