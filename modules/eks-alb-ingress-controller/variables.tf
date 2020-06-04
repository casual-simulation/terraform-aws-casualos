variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster."
}

variable "cluster_oidc_issuer_url" {
  type        = string
  description = "The URL of the OpenID Connect Issuer that the IRSA role should use. Usually, this is the OIDC issuer url of the EKS cluster."
}

variable "alb_service_account_name" {
  type        = string
  default     = "alb-ingress-controller"
  description = "The name of the service account that should be created for the ALB ingress controller."
}

variable "alb_controller_version" {
  type        = string
  default     = "v1.1.7"
  description = "The docker tag version that should be used for the ingress controller container."
}

variable "alb_controller_image" {
  type        = string
  default     = "docker.io/amazon/aws-alb-ingress-controller"
  description = "The docker image that should be used for the deployment's container."
}