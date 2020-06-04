# The Policy Document that gives a user/role the ability
# to create, delete, and mount volumes.
data "aws_iam_policy_document" "csi" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:AttachVolume",
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteSnapshot",
      "ec2:DeleteTags",
      "ec2:DeleteVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
      "ec2:DetachVolume",
      "ec2:ModifyVolume"
    ]

    resources = [
      "*",
    ]
  }
}

# Create a policy for the CSI driver
resource "aws_iam_policy" "csi" {
  name   = "${var.cluster_name}-csi-policy"
  policy = data.aws_iam_policy_document.csi.json
}

# Create an IAM role that is assumable using OpenID Connect (OIDC)
# This allows the specified service accounts authenticated by the Cluster OIDC URL to
# assume this role and get access to all the resources it specifies.
# In this case, we're creating a role that allows the EBS CSI driver in Kubernetes to create/mount volumes.
module "csi_role" {
  source       = "git::https://github.com/casual-simulation/terraform-aws-iam//modules/iam-assumable-role-with-oidc?ref=v2.11.0"
  create_role  = true
  role_name    = "${var.cluster_name}-csi-role"
  provider_url = replace(var.cluster_oidc_issuer_url, "https://", "")

  # The list of policies that should be attached to the role.
  role_policy_arns = [aws_iam_policy.csi.arn]

  # The list of subjects (e.g. service accounts) that are allowed to assume this role
  oidc_fully_qualified_subjects = [
    # These were taken from the service accounts that the EBS CSI Driver creates here:
    # https://github.com/kubernetes-sigs/aws-ebs-csi-driver/tree/master/aws-ebs-csi-driver/templates
    "system:serviceaccount:kube-system:ebs-csi-controller-sa",
    "system:serviceaccount:kube-system:ebs-snapshot-controller"
  ]
}

# Install the CSI Driver into the cluster.
resource "helm_release" "csi_driver" {
  name      = "aws-ebs-csi-driver"
  namespace = "kube-system"
  chart     = "https://github.com/kubernetes-sigs/aws-ebs-csi-driver/releases/download/v0.5.0/helm-chart.tgz"

  set {
    name  = "enableVolumeScheduling"
    value = true
  }

  # Enable volume resizing to allow us to resize the MongoDB and Redis volumes
  # dynamically.
  set {
    name  = "enableVolumeResizing"
    value = true
  }

  # Enable volume snapshotting to allow us to create volume snapshots inside the
  # cluster.
  set {
    name  = "enableVolumeSnapshot"
    value = true
  }

  # Specify the CSI Service Role ARN
  # that should be used for the controller and snapshot services
  values = [
    yamlencode({
      serviceAccount = {
        controller = {
          annotations = {
            "eks.amazonaws.com/role-arn" = module.csi_role.this_iam_role_arn
          }
        }
        snapshot = {
          annotations = {
            "eks.amazonaws.com/role-arn" = module.csi_role.this_iam_role_arn
          }
        }
      }
    })
  ]
}

# Create a storage class that uses the EBS CSI driver.
# This is named as resizable because it allows volumes to be expanded.
resource "kubernetes_storage_class" "ebs-csi" {
  metadata {
    name = var.ebs_storage_class_name
  }
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
}