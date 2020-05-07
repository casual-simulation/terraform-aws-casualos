terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
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

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.default.main_route_table_id
  gateway_id             = aws_internet_gateway.default.id
  destination_cidr_block = "0.0.0.0/0"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# A security group for the ELB so it is accessible via the web
# resource "aws_security_group" "elb" {
#   name        = "terraform_example_elb"
#   description = "Used in the terraform"
#   vpc_id      = "${aws_vpc.default.id}"

#   # HTTP access from anywhere
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   # outbound internet access
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "casualos-security-group"
  description = "Used in the terraform"
  vpc_id      = aws_vpc.default.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from any other instance in the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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

  # Add the deployer SSH key to the instance
  key_name = aws_key_pair.deployer.key_name

  # Use the configured security group
  vpc_security_group_ids = [aws_security_group.default.id]

  # Use the subnet we created
  subnet_id = aws_subnet.default.id
}