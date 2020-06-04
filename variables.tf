variable "aws_profile" {
  type        = string
  default     = ""
  description = "The AWS Named Profile that should be used to access the AWS_ACCESS_KEY and AWS_SECRET_KEY values."
}

variable "aws_region" {
  default     = "us-east-1"
  description = "The AWS Region that the instance should be deployed to."
}

variable "deployer_ssh_public_key" {
  type        = string
  description = "The Public SSH Key (authorized_keys format) that should be automatically added to the new instance."
}

variable "zerotier_network" {
  type        = string
  default     = ""
  description = "The ID of the ZeroTier network that should be automatically joined by the instance."
}

variable "zerotier_api_key" {
  type        = string
  default     = ""
  description = "The ZeroTier API key that should be used to automatically authorize the instance."
}

variable "zerotier_network_cidr" {
  type        = string
  default     = "172.29.0.0/16"
  description = "The CIDR address of the ZeroTier network. Used to allow access from other devices on the ZeroTier network."
}

variable "aws_route53_hosted_zone_name" {
  type        = string
  description = "The name of the hosted zone that the new domain should be created in."
}

variable "aws_route53_subdomain_name" {
  type        = string
  description = "The subdomain that should be used for the instance."
}
