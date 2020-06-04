variable "cluster_name" {
  default     = "eks-spaceladders"
  description = "The name of the cluster. Used to give AWS resources unique names."
}

variable "aws_region" {
  default     = "us-east-1"
  description = "AWS region"
}

variable "aws_profile" {
  type        = string
  default     = ""
  description = "The configured profile that should be used to communicate with the AWS API. See https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html"
}

variable "write_kubeconfig" {
  default     = false
  description = "Whether to write a kubeconfig file after the cluster has been created."
}

variable "aws_eks_group_name" {
  type        = string
  default     = ""
  description = "The IAM Group Name that contains all the users that should be mapped into Kubernetes as masters."
}

variable "casualos_version" {
  type = string
  default = "v1.1.4"
  description = "The version of CasualOS to deploy."
}

variable "mongodb_chart_version" {
  type = string
  default = "7.14.5"
  description = "The version of the MongoDB Helm chart to deploy. See https://github.com/bitnami/charts/tree/master/bitnami/mongodb"
}

variable "redis_chart_version" {
  type = string
  default = "10.6.17"
  description = "The version of the Redis Helm chart to deploy. See https://github.com/bitnami/charts/tree/master/bitnami/redis"
}

variable "dashboard_chart_version" {
  type = string
  default = "2.0.1"
  description = "The version of the Dashboard Helm chart to deploy. See https://kubernetes.github.io/dashboard/"
}

variable "dashboard_image_tag" {
   default = "v2.0.0-rc3"
   description = "The Docker image tag that should be used for the Kubernetes dashboard deployment."
}

variable "metrics_chart_version" {
  type = string
  default = "2.11.1"
  description = "The version of the Metrics Helm chart to deploy. Pulled from this repository: https://kubernetes-charts.storage.googleapis.com"
}
