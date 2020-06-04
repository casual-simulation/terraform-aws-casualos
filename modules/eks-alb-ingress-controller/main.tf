

# The policy document that is attached to the kubernetes nodes IAM role
# which allows managing Application Load Balancers.
data "aws_iam_policy_document" "alb" {
  statement {
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "acm:GetCertificate"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcs",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:RevokeSecurityGroupIngress"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:SetWebACL"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:GetServerCertificate",
      "iam:ListServerCertificates"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "waf-regional:GetWebACLForResource",
      "waf-regional:GetWebACL",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "tag:GetResources",
      "tag:TagResources"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "waf:GetWebACL"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "shield:DescribeProtection",
      "shield:GetSubscriptionState",
      "shield:DeleteProtection",
      "shield:CreateProtection",
      "shield:DescribeSubscription",
      "shield:ListProtections"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL"
    ]
    resources = ["*"]
  }
}

# Create a policy for the ALBs
resource "aws_iam_policy" "alb" {
  name   = "${var.cluster_name}-alb-policy"
  policy = data.aws_iam_policy_document.alb.json
}

# Create an IAM role that is assumable using OpenID Connect (OIDC)
# This allows the specified service accounts authenticated by the Cluster OIDC URL to
# assume this role and get access to all the resources it specifies.
# In this case, we're creating a role that allows the ALB ingress controller in Kubernetes to create ALBs.
module "alb_role" {
  source       = "git::https://github.com/casual-simulation/terraform-aws-iam//modules/iam-assumable-role-with-oidc?ref=v2.11.0"
  create_role  = true
  role_name    = "${var.cluster_name}-alb-role"
  provider_url = replace(var.cluster_oidc_issuer_url, "https://", "")

  # The list of policies that should be attached to the role.
  role_policy_arns = [aws_iam_policy.alb.arn]

  # The list of subjects (e.g. service accounts) that are allowed to assume this role
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:${var.alb_service_account_name}"]
}

# The alb-ingress-controller service account is used
# by the ALB Ingress Controller to authenticate to AWS to create/destroy ALBs
resource "kubernetes_service_account" "alb" {
  metadata {
    name      = var.alb_service_account_name
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = var.alb_service_account_name
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = module.alb_role.this_iam_role_arn
    }
  }
}

# The role that the ingress controller needs to access the correct resources.
resource "kubernetes_cluster_role" "alb" {
  metadata {
    name = "alb-ingress-controller"
    labels = {
      "app.kubernetes.io/name" = "alb-ingress-controller"
    }
  }

  rule {
    api_groups = [
      "",
      "extensions"
    ]

    resources = [
      "configmaps",
      "endpoints",
      "events",
      "ingresses",
      "ingresses/status",
      "services",
    ]

    verbs = [
      "create",
      "get",
      "list",
      "update",
      "watch",
      "patch",
    ]
  }

  rule {
    api_groups = [
      "",
      "extensions"
    ]

    resources = [
      "nodes",
      "pods",
      "secrets",
      "services",
      "namespaces",
    ]

    verbs = [
      "get",
      "list",
      "watch",
    ]
  }
}

# Bind the alb cluster role to the alb service account.
resource "kubernetes_cluster_role_binding" "alb" {
  metadata {
    name = "alb-ingress-controller"
    labels = {
      "app.kubernetes.io/name" = "alb-ingress-controller"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.alb.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.alb.metadata[0].name
    namespace = kubernetes_service_account.alb.metadata[0].namespace
  }
}

# Deploy the ALB ingress controller
resource "kubernetes_deployment" "alb" {
  depends_on = [kubernetes_cluster_role_binding.alb]

  metadata {
    name      = "alb-ingress-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "alb-ingress-controller"
    }
  }

  spec {
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "alb-ingress-controller"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "alb-ingress-controller"
        }
      }

      spec {
        container {
          name  = "alb-ingress-controller"
          image = "${var.alb_controller_image}:${var.alb_controller_version}"
          args = [
            # Limit the namespace where this ALB Ingress Controller deployment will
            # resolve ingress resources. If left commented, all namespaces are used.
            # "--watch-namespace=your-k8s-namespace",

            # Setting the ingress-class flag below ensures that only ingress resources with the
            # annotation kubernetes.io/ingress.class: "alb" are respected by the controller. You may
            # choose any class you'd like for this controller to respect.
            "--ingress-class=alb",

            # REQUIRED
            # Name of your cluster. Used when naming resources created
            # by the ALB Ingress Controller, providing distinction between
            # clusters.
            "--cluster-name=${var.cluster_name}"

            # AWS VPC ID this ingress controller will use to create AWS resources.
            # If unspecified, it will be discovered from ec2metadata.
            # "--aws-vpc-id=vpc-xxxxxx"

            # AWS region this ingress controller will operate in.
            # If unspecified, it will be discovered from ec2metadata.
            # List of regions: http://docs.aws.amazon.com/general/latest/gr/rande.html#vpc_region
            # "--aws-region=us-west-1"

            # Enables logging on all outbound requests sent to the AWS API.
            # If logging is desired, set to true.
            # - --aws-api-debug
            # Maximum number of times to retry the aws calls.
            # defaults to 10.
            # "--aws-max-retries=10"
          ]
        }

        # Specify the service account that each pod should use.
        # This should be the same service account that we setup above
        # to ensure that it gets the correct permissions.
        service_account_name = kubernetes_service_account.alb.metadata[0].name

        # Tell Terraform to automatically mount the service account token for the deployment.
        # Normally, this is true by default but Terraform differs from the Kubernetes defaults.
        # See https://github.com/terraform-providers/terraform-provider-kubernetes/issues/38
        automount_service_account_token = true
      }
    }
  }
}
