# This file sets up the EKS cluster and the Kubernetes and Helm providers.

locals {
  cluster_name             = "${var.cluster_name}-${random_string.suffix.result}"
  alb_service_account_name = "alb-ingress-controller"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

# Get the group of users that should be added to the Kubernetes
# users map.
data "aws_iam_group" "eks_users" {
  group_name = var.aws_eks_group_name
}

# Specify the Kubernetes provider so that Terraform knows how to talk to the cluster
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.9"
}

provider "helm" {
  version = "~> 1.2.1"
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    token                  = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    load_config_file       = false
  }
}

# Create an EKS cluster
module "eks" {
  # TODO: Update when a new version of this module is released
  source       = "git::https://github.com/terraform-aws-modules/terraform-aws-eks?ref=05cd78593a2d7e1e9fe5cb591ba07e3a3bc3fbc9"
  cluster_name = local.cluster_name

  # This is the list of subnets that the EKS cluster will put worker nodes in.
  # Note that non-worker nodes like load balancers can be created in other subnets.
  # Also note that we're using the private subnets here because the worker nodes don't need
  # direct internet access. The only internet access they should have is via a load balancer.
  subnets = [aws_subnet.private1.id, aws_subnet.private2.id]

  # Tags that should be applied to the EKS cluster.
  # No special meaning here.
  tags = {
    Environment = "dev"
    GithubRepo  = "eks.spaceladders.com"
    GithubOrg   = "casual-simulation"
  }

  # The ID of the VPC that all cluster resources should be created inside of.
  # AWS will use the tags on the subnets to determine where to place some resources.
  vpc_id = aws_vpc.default.id

  # Enable a OpenID Connect endpoint for the cluster
  # to allow service accounts to be given AWS policy roles.
  enable_irsa = true

  write_kubeconfig = var.write_kubeconfig

  # The groups of worker nodes that should be created.
  # These can be scaled by changing the desired capacity.
  # There are also lots of other options that can be specified.
  # See https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/local.tf#L34 for a full list.
  worker_groups = [
    {
      name                 = "worker-group-1"
      instance_type        = "t3.small"
      additional_userdata  = "echo foo bar"
      asg_desired_capacity = 1

      # We can specify additional security groups that should be applied to each of the workers
      # in this group if we want.
      additional_security_group_ids = [aws_security_group.allow_vpc_ssh.id]
    },
    {
      name                          = "worker-group-2"
      instance_type                 = "t3.medium"
      additional_userdata           = "echo foo bar"
      additional_security_group_ids = [aws_security_group.allow_vpc_ssh.id]
      asg_desired_capacity          = 1
    },
  ]

  map_users = [for u in data.aws_iam_group.eks_users.users : {
    userarn  = u.arn
    username = u.user_name
    groups   = ["system:masters"]
  }]
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}