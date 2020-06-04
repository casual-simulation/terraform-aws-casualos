
output "alb_ingress_class" {
    value = "alb"
    description = "The ingress class that the deployed ingress controller uses."
}

output "alb_service_account" {
    value = kubernetes_service_account.alb
    description = "The service account that was created for the ingress controller deployment."
}

output "alb_cluster_role" {
    value = kubernetes_cluster_role.alb
    description = "The cluster role that was created for the ingress controller."
}

output "alb_cluster_role_binding" {
    value = kubernetes_cluster_role_binding.alb
    description = "The cluster role binding for the cluster role and service account that were created."
}

output "alb_deployment" {
    value = kubernetes_deployment.alb
    description = "The deployment for the ALB Ingress Controller."
}

output "alb_role_arn" {
    value = module.alb_role.this_iam_role_arn
    description = "The ARN of the IAM role that was created for the ALB ingress controller."
}