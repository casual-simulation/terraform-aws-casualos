
variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster."
}

variable "cluster_oidc_issuer_url" {
  type        = string
  description = "The URL of the OpenID Connect Issuer that the IRSA role should use. Usually, this is the OIDC issuer url of the EKS cluster."
}

variable "ebs_storage_class_name" {
  default     = "ebs-sc-resizable"
  description = "The name of the storage class that should be created for the EBS driver."
}