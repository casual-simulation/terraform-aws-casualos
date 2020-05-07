
variable "instance_type" {
  default = "t3.micro"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "aws_ami_name_filter" {
  default = "nomad-consul-docker-ubuntu20-*"
}

variable "aws_ami_owner" {
  default = "casualsimulation"
}

variable "deployer_ssh_public_key" {
}