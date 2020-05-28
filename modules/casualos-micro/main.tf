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
    zerotier_network = var.zerotier_network
    zerotier_api_key = var.zerotier_api_key
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
  name = "${var.name}-alb"
  internal = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.load_balancer.id]
  subnets = aws_subnet.default.*.id
}

resource "aws_lb_target_group" "instances" {
  name = "${var.name}-tg-instances"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.default.id
}

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "load_balancer" {
  name        = "${var.name}-sg-load_balancer"
  description = "Used by the load balancer"
  vpc_id      = aws_vpc.default.id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
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
  name        = "${var.name}-sg-instance"
  description = "Used for EC2 instances running CasualOS"
  vpc_id      = aws_vpc.default.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0", "10.0.0.0/16", var.zerotier_network_cidr]
  }

  # HTTP access from any other instance in the VPC and ZeroTier
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", var.zerotier_network_cidr]
  }

  # AUX access from inside the VPC and ZeroTier
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", var.zerotier_network_cidr]
  }

  # Nomad access from inside the VPC and ZeroTier
  ingress {
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", var.zerotier_network_cidr]
  }

  # MongoDB access from inside the VPC and ZeroTier
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", var.zerotier_network_cidr]
  }

  # Redis access from inside the VPC and ZeroTier
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", var.zerotier_network_cidr]
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
  key_name   = "${var.name}-deployer-key"
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
  name = "${var.name}-instance-role"
  path = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust_policy.json
}

# The IAM instance profile that the server uses
resource "aws_iam_instance_profile" "server" {
  name = "${var.name}-instance-profile"
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

# The EC2 instance that represents the server
resource "aws_instance" "server" {
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
    Name = "${var.name}-instance"
  }
}

# Attach port 80 of the instance to the instances load balancer target group
resource "aws_lb_target_group_attachment" "server" { 
    target_group_arn = aws_lb_target_group.instances.arn
    target_id = aws_instance.server.id

    # Use port 3000 when contacting this instance from the target group
    port = 3000
}

# Resource policy that lets casualos_server mount EBS volumes
resource "aws_iam_role_policy" "mount_ebs_volumes" {
  name   = "${var.name}-mount-ebs-volumes"
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

# EBS volume used by MongoDB to store persistent data
# Needs to be in the same availabilit zone as the instance
resource "aws_ebs_volume" "mongodb" {
  availability_zone = aws_subnet.default.0.availability_zone
  size              = var.aws_ec2_block_size
}

resource "aws_iam_role" "dlm_lifecycle_role" {
  name = "dlm-lifecycle-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "dlm.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "dlm_lifecycle" {
  name = "dlm-lifecycle-policy"
  role = aws_iam_role.dlm_lifecycle_role.id

  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Action": [
            "ec2:CreateSnapshot",
            "ec2:DeleteSnapshot",
            "ec2:DescribeVolumes",
            "ec2:DescribeSnapshots"
         ],
         "Resource": "*"
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:CreateTags"
         ],
         "Resource": "arn:aws:ec2:*::snapshot/*"
      }
   ]
}
EOF
}

resource "aws_dlm_lifecycle_policy" "mongodb_backup" {
  description        = "Backups for ${aws_ebs_volume.mongodb.id} (MongoDB Volume)"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "${var.aws_snapshot_retain_days} days of daily snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["23:45"]
      }

      retain_rule {
        count = var.aws_snapshot_retain_days
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
      }

      copy_tags = false
    }

    target_tags = {
      Snapshot = "true"
    }
  }
}

data "template_file" "casualos_job" {
  template = file("${path.module}/lib/casualos.hcl.tpl")

  vars = {
    aws_region = var.aws_region
    consul_dns_server = aws_instance.server.private_ip
  }
}

data "template_file" "aws_ebs_controller_job" {
  template = file("${path.module}/lib/aws-ebs-controller.hcl.tpl")

  vars = {
    aws_region = var.aws_region
  }
}
data "template_file" "aws_ebs_nodes_job" {
  template = file("${path.module}/lib/aws-ebs-nodes.hcl.tpl")

  vars = {
    aws_region = var.aws_region
  }
}

data "template_file" "aws_ebs_volume" {
  template = file("${path.module}/lib/aws-ebs-volume.hcl.tpl")

  vars = {
    aws_ebs_volume_name = "mongodb"
    aws_ebs_volume_id = aws_ebs_volume.mongodb.id
    csi_plugin_id = "aws-ebs0"
  }
}