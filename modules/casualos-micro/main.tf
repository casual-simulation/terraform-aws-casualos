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


data "template_file" "nomad_config" {
  template = file("${path.module}/lib/nomad/nomad.hcl.tpl")

  vars = {
    aws_region = var.aws_region
  }
}

data "template_file" "nomad_service" {
  template = file("${path.module}/lib/nomad/nomad.service.tpl")

  vars = {}
}

data "template_file" "cloud_config" {
  template = file("${path.module}/lib/cloud_config.yml.tpl")

  vars = {
    consul_config  = base64encode(data.template_file.consul_config.rendered)
    consul_service = base64encode(data.template_file.consul_service.rendered)
    nomad_config  = base64encode(data.template_file.nomad_config.rendered)
    nomad_service = base64encode(data.template_file.nomad_service.rendered)
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

# Create a load balancer that provides access to the system
resource "aws_lb" "load_balancer" { 
  name = "casualos-alb"
  internal = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.load_balancer.id]
  subnets = [aws_subnet.default.id]
}

resource "aws_lb_target_group" "instances" {
  name = "casualos-tg-instances"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.default.id
}

# The HTTP listener for the load balancer
resource "aws_lb_listener" "load_balancer_http" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.instances.arn
  }
}

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "load_balancer" {
  name        = "casualos-sg-load_balancer"
  description = "Used by the load balancer"
  vpc_id      = aws_vpc.default.id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "instance" {
  name        = "casualos-sg-instance"
  description = "Used for EC2 instances running CasualOS"
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

  # Nomad access from anywhere
  # TODO: Make this secure
  ingress {
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
  key_name   = "casualos-deployer-key"
  public_key = var.deployer_ssh_public_key
}

# Policy document that allows
# EC2 instances to assume roles with this trust policy.
data "aws_iam_policy_document" "ec2_trust_policy" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# The AWS Role for the server EC2 instance
resource "aws_iam_role" "auxPlayer_role" {
  name = "casualos-instance-role"
  path = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust_policy.json
}

# The IAM instance profile that the server uses
resource "aws_iam_instance_profile" "server" {
  name = "auxPlayer_profile"
  role = aws_iam_role.auxPlayer_role.name
}

# The launch configuration that specifies how to
# create an EC2 instance with CasualOS
resource "aws_launch_configuration" "server" { 
  name_prefix = "casualos-lc"
  image_id = data.aws_ami.server_ami.id
  instance_type = var.instance_type
  user_data     = data.template_cloudinit_config.cloudinit.rendered
  key_name = aws_key_pair.deployer.key_name

  iam_instance_profile = aws_iam_instance_profile.server.id
  security_groups = [aws_security_group.instance.id]
  
  associate_public_ip_address = true

  # Tell Terraform to create a new instance before destroying the old one
  lifecycle {
    create_before_destroy = true
  }
}

# The Autoscaling group that the CasualOS instances run in.
# This is useful because AWS will be able to automatically create a new instance
# should one fail.
resource "aws_autoscaling_group" "server" { 
  name = "auxPlayer-asg"
  min_size = 1
  max_size = 1
  desired_capacity = 1

  launch_configuration = aws_launch_configuration.server.name
  target_group_arns = [aws_lb_target_group.instances.arn]
  vpc_zone_identifier = [aws_subnet.default.id]
}

# # The EC2 instance that represents the server
# resource "aws_instance" "server" {
#   ami           = data.aws_ami.server_ami.id
#   instance_type = var.instance_type
#   user_data     = data.template_cloudinit_config.cloudinit.rendered
  
#   # Add the deployer SSH key to the instance
#   key_name = aws_key_pair.deployer.key_name

#   iam_instance_profile = aws_iam_instance_profile.server.id

#   # Use the configured security group
#   vpc_security_group_ids = [aws_security_group.default.id]

#   # Use the subnet we created
#   subnet_id = aws_subnet.default.id

#   tags = {
#     Name = var.aws_instance_name
#   }
# }

# Resource policy that lets auxPlayer_role mount EBS volumes
resource "aws_iam_role_policy" "mount_ebs_volumes" {
  name   = "mount-ebs-volumes"
  role   = aws_iam_role.auxPlayer_role.id
  policy = data.aws_iam_policy_document.mount_ebs_volumes.json
}

# The policy document that gives the EC2 instance the ability to
# List, mount, and attach EBS volumes.
data "aws_iam_policy_document" "mount_ebs_volumes" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeVolume*",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
    ]
    resources = ["*"]
  }
}

# EBS volume used by MongoDB to store persistent data
resource "aws_ebs_volume" "mongodb" {
  availability_zone = aws_subnet.default.availability_zone
  size              = var.aws_ec2_block_size
}

data "template_file" "casualos_job" {
  template = file("${path.module}/lib/casualos.hcl.tpl")

  vars = {
    aws_region = var.aws_region
  }
}

# The nomad job file that can be used to run CasualOS.
resource "local_file" "casualos_job_file" {
    content     = data.template_file.casualos_job.rendered
    filename = "${path.module}/out/casualos.hcl"
}