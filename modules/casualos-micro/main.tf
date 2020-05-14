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

# The list of availablility zones for the region
data "aws_availability_zones" "available" {}

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
  # Make 2 subnets because we need subnets in 2 different
  # availability zones for the load balancer.
  count = "2"

  vpc_id                  = aws_vpc.default.id

  # Allocate CIDR blocks in 8 bit chuncks
  # e.g. #1 = (10.0.1.0/8)
  #      #2 = (10.0.2.0/8)
  cidr_block        = cidrsubnet(aws_vpc.default.cidr_block, 8, count.index)

  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true
}

# Create a load balancer that provides access to the system
resource "aws_lb" "load_balancer" { 
  name = "casualos-alb"
  internal = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.load_balancer.id]
  subnets = aws_subnet.default.*.id
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
resource "aws_iam_role" "casualos_server" {
  name = "casualos-instance-role"
  path = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust_policy.json
}

# The IAM instance profile that the server uses
resource "aws_iam_instance_profile" "server" {
  name = "casualos-instance-profile"
  role = aws_iam_role.casualos_server.name
}

# TODO: Use AutoScaling groups with the cluster implementation
# # The launch configuration that specifies how to
# # create an EC2 instance with CasualOS
# resource "aws_launch_configuration" "server" { 
#   name_prefix = "casualos-lc"
#   image_id = data.aws_ami.server_ami.id
#   instance_type = var.instance_type
#   user_data     = data.template_cloudinit_config.cloudinit.rendered
#   key_name = aws_key_pair.deployer.key_name

#   iam_instance_profile = aws_iam_instance_profile.server.id
#   security_groups = [aws_security_group.instance.id]
  
#   associate_public_ip_address = true

#   # Tell Terraform to create a new instance before destroying the old one
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # The Autoscaling group that the CasualOS instances run in.
# # This is useful because AWS will be able to automatically create a new instance
# # should one fail.
# resource "aws_autoscaling_group" "server" { 
#   name = "auxPlayer-asg"
#   min_size = 1
#   max_size = 1
#   desired_capacity = 1

#   launch_configuration = aws_launch_configuration.server.name
#   target_group_arns = [aws_lb_target_group.instances.arn]
#   vpc_zone_identifier = [aws_subnet.default.id]
# }

# The Secret that the instance will update with the bootstrap token information
resource "aws_secretsmanager_secret" "nomad_bootstrap_token" { 
  name = "casualos/nomad/BootstrapToken"
}

# The EC2 instance that represents the server
resource "aws_instance" "server" {
  # Needs the bootstrap token secret to be created first
  depends_on = [aws_secretsmanager_secret.nomad_bootstrap_token]

  ami           = data.aws_ami.server_ami.id
  instance_type = var.instance_type
  user_data     = data.template_cloudinit_config.cloudinit.rendered
  
  # Add the deployer SSH key to the instance
  key_name = aws_key_pair.deployer.key_name

  iam_instance_profile = aws_iam_instance_profile.server.id

  # Use the configured security group
  vpc_security_group_ids = [aws_security_group.instance.id]

  # Use the subnet we created
  subnet_id = aws_subnet.default.0.id

  # Tell AWS to give the instance a public IP so that we 
  # can SSH directly into it
  associate_public_ip_address = true

  tags = {
    Name = var.aws_instance_name
  }
}

# Attach port 80 of the instance to the instances load balancer target group
resource "aws_lb_target_group_attachment" "server" { 
    target_group_arn = aws_lb_target_group.instances.arn
    target_id = aws_instance.server.id

    # Use port 80 when contacting this instance from the target group
    port = 80
}

# Resource policy that lets casualos_server mount EBS volumes
resource "aws_iam_role_policy" "mount_ebs_volumes" {
  name   = "mount-ebs-volumes"
  role   = aws_iam_role.casualos_server.id
  policy = data.aws_iam_policy_document.mount_ebs_volumes.json
}

# The policy document that gives the EC2 instance the ability to
# List, mount, and attach EBS volumes.
data "aws_iam_policy_document" "mount_ebs_volumes" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:AttachVolume",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteSnapshot",
      "ec2:DeleteTags",
      "ec2:DeleteVolume",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DetachVolume",
      "ec2:ModifyVolume"
    ]
    resources = ["*"]
  }
}

# Resource policy that lets casualos_server set secretsmanager secrets
resource "aws_iam_role_policy" "put_secretsmanager_secrets" {
  name   = "put-secretsmanager-secrets"
  role   = aws_iam_role.casualos_server.id
  policy = data.aws_iam_policy_document.put_secretsmanager_secrets.json
}

# The policy document that gives the EC2 instance the ability to
# Set a secret's value.
data "aws_iam_policy_document" "put_secretsmanager_secrets" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:PutSecretValue",
    ]
    resources = [
      # Allow access only to the nomad bootstrap token secret
      aws_secretsmanager_secret.nomad_bootstrap_token.arn
    ]
  }
}

# EBS volume used by MongoDB to store persistent data
# Needs to be in the same availabilit zone as the instance
resource "aws_ebs_volume" "mongodb" {
  availability_zone = aws_subnet.default.0.availability_zone
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

data "template_file" "aws_ebs_controller_job" {
  template = file("${path.module}/lib/aws-ebs-controller.hcl.tpl")

  vars = {
    aws_region = var.aws_region
  }
}

# The nomad job file that can be used to run CasualOS.
resource "local_file" "aws_ebs_controller_job_file" {
    content     = data.template_file.aws_ebs_controller_job.rendered
    filename = "${path.module}/out/aws-ebs-controller.hcl"
}

data "template_file" "aws_ebs_nodes_job" {
  template = file("${path.module}/lib/aws-ebs-nodes.hcl.tpl")

  vars = {
    aws_region = var.aws_region
  }
}

# The nomad job file that can be used to run CasualOS.
resource "local_file" "aws_ebs_nodes_job_file" {
    content     = data.template_file.aws_ebs_nodes_job.rendered
    filename = "${path.module}/out/aws-ebs-nodes.hcl"
}

data "template_file" "aws_ebs_volume" {
  template = file("${path.module}/lib/aws-ebs-volume.hcl.tpl")

  vars = {
    aws_ebs_volume_name = "mongodb"
    aws_ebs_volume_id = aws_ebs_volume.mongodb.id
    csi_plugin_id = "aws-ebs0"
  }
}

# The nomad job file that can be used to run CasualOS.
resource "local_file" "aws_ebs_volume_file" {
    content     = data.template_file.aws_ebs_volume.rendered
    filename = "${path.module}/out/abs-ebs-volume.hcl"
}