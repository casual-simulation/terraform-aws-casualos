
variable "name" {
    type = string
    description = "The name of the deployment. Must be all lowercase and not contain any symbols or spaces. (hyphens are allowed)"
}

variable "instance_type" {
  default = "t3.micro"
  description = "The AWS EC2 Instance type that should be deployed."
}

variable "aws_profile" {
    type = string
    default = ""
    description = "The AWS Named Profile that should be used to access the AWS_ACCESS_KEY and AWS_SECRET_KEY values."
}

variable "aws_region" {
  default = "us-east-1"
  description = "The AWS Region that the instance should be deployed to."
}

variable "aws_ami_name_filter" {
  default = "nomad-consul-docker-ubuntu20-*"
  description = "The AWS describe-images name filter that determines which AMI should be used for the new instance."
}

variable "aws_ami_owner" {
  default = "self"
  description = "The AWS Account ID or alias that owns the AMI. Use 'self' to indicate the current account."
}

variable "deployer_ssh_public_key" {
  type = string
  description = "The Public SSH Key (authorized_keys format) that should be automatically added to the new instance."
}

variable "aws_ec2_block_size" {
  default = 40
  description = "The size of the disk (in GiBs) that should be used to store CasualOS data."
}

variable "aws_snapshot_retain_days" {
  default = 4
  description = "The number of days that volume snapshots should be retained for."
}


variable "zerotier_network" {
  type = string
  default = ""
  description = "The ID of the ZeroTier network that should be automatically joined by the instance."
}

variable "zerotier_api_key" {
  type = string
  default = ""
  description = "The ZeroTier API key that should be used to automatically authorize the instance."
}

variable "zerotier_network_cidr" {
  type = string
  default = "172.29.0.0/16"
  description = "The CIDR address of the ZeroTier network. Used to allow access from other devices on the ZeroTier network."
}