#############################################
# Bastion EC2 (with SSM). Reuses the
# existing instance profile ec2_profile.
#############################################

# AMI Amazon Linux 2 (x86_64) con SSM Agent ya instalado
data "aws_ami" "al2" {
  owners      = ["137112412989"] # Amazon
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# If you don't pass bastion_subnet_id, use the 1st public subnet created
locals {
  bastion_subnet_id_effective = var.bastion_subnet_id != "" ? var.bastion_subnet_id : aws_subnet.public[0].id
}

resource "aws_instance" "bastion" {
  count                       = var.enable_bastion ? 1 : 0
  ami                         = data.aws_ami.al2.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = local.bastion_subnet_id_effective
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion_sg[0].id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = var.bastion_key_name

  # Re-crear si cambia el user_data
  user_data_replace_on_change = true
  user_data                   = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    dnf install -y ca-certificates curl || true

    if ! rpm -q amazon-ssm-agent >/dev/null 2>&1; then
      dnf install -y amazon-ssm-agent || true
    fi
    if ! rpm -q amazon-ssm-agent >/dev/null 2>&1; then
      curl -fsSL -o /tmp/amazon-ssm-agent.rpm \
        https://s3.${var.aws_region}.amazonaws.com/amazon-ssm-${var.aws_region}/latest/linux_amd64/amazon-ssm-agent.rpm
      dnf install -y /tmp/amazon-ssm-agent.rpm || rpm -Uvh --replacepkgs /tmp/amazon-ssm-agent.rpm
    fi

    systemctl enable --now amazon-ssm-agent || true
    systemctl enable --now chronyd || true
  EOF

  tags = merge(local.common_tags, { Name = "${var.project}-bastion" })
}

