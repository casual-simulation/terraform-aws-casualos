terraform {
  required_version = ">= 0.12"
}

resource "aws_instance" "server" { 
    ami = "ami-TODO"
    instance_type = var.instance_type
}