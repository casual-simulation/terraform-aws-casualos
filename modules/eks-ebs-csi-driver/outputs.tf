
output "ebs_storage_class" {
  value       = kubernetes_storage_class.ebs-csi
  description = "The Kubernetes storage class resource that was created for the EBS CSI driver."
}

output "csi_role_arn" {
  value       = module.csi_role.this_iam_role_arn
  description = "The ARN of the IAM role that was created for the CSI driver."
}