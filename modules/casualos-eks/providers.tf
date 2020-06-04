provider "aws" {
  version = ">= 2.28.1"
  region  = var.aws_region
  profile = var.aws_profile
}