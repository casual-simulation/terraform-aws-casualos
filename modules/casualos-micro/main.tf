terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region = var.aws_region
}

data "template_file" "consul_config" {
  template = file("${path.module}/lib/consul/consul.hcl.tpl")

  vars = {
    aws_region = var.aws_region
  }
}

data "template_file" "consul_service" {
  template = file("${path.module}/lib/consul/consul.service.tpl")

  vars = {}
}

data "template_file" "cloud_config" {
  template = file("${path.module}/lib/cloud_config.yml.tpl")

  vars = {
    consul_config  = base64encode(data.template_file.consul_config.rendered)
    consul_service = base64encode(data.template_file.consul_service.rendered)
  }
}

data "template_cloudinit_config" "cloudinit" {
  gzip          = true
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.cloud_config.rendered
  }
}

data "aws_ami" "server_ami" {
  most_recent = true
  owners      = [var.aws_ami_owner]

  filter {
    name   = "name"
    values = [var.aws_ami_name_filter]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.deployer_ssh_public_key
}

resource "aws_instance" "server" {
  ami           = data.aws_ami.server_ami.id
  instance_type = var.instance_type
  user_data     = data.template_cloudinit_config.cloudinit.rendered
}