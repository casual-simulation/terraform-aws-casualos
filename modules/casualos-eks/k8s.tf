# This file sets up the Kubernetes resources that CasualOS
# needs to function.
# In particular:
# - A EBS CSI Driver for MongoDB and Redis storage.
# - A ALB Ingress Controller for ingress to CasualOS.
# - MongoDB
# - Redis
# - CasualOS

# The admin service account for accessing the dashboard
resource "kubernetes_service_account" "admin" {
  metadata {
    name      = "admin-user"
    namespace = "kube-system"
  }
}

# Bind the admin service account to the cluster-admin role
# This will let the admin-user do anything in the cluster
resource "kubernetes_cluster_role_binding" "adminUserClusterAdmin" {
  metadata {
    name = "admin-user"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "admin-user"
    namespace = "kube-system"
  }
}

module "csi" {
  source                  = "../eks-ebs-csi-driver"
  cluster_name            = local.cluster_name
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
}

module "alb" {
  source                  = "../eks-alb-ingress-controller"
  cluster_name            = local.cluster_name
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
}

# Install the kubernetes dashboard
resource "helm_release" "kube_dashboard" {
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"

  # See https://github.com/helm/charts/issues/3104 for "fun"
  namespace = "kube-system"

  version = var.dashboard_chart_version

  # Use this version because it is the most recent that supported Kubernetes
  # version 1.16
  set {
    name  = "image.tag"
    value = var.dashboard_image_tag
  }

  # Enable the metrics scraper pod to get metrics from the metrics
  # server.
  set {
    name  = "metricsScraper.enabled"
    value = true
  }
}

# Install the metrics server.
# This will pull metrics (like CPU & memory) from each node and pod
# and make it available to the dashboard.
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-charts.storage.googleapis.com"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = var.metrics_chart_version
}

# Install Redis into the cluster.
# Redis is used by CasualOS for caching data.
resource "helm_release" "redis" {
  name      = "redis"
  namespace = "default"

  # Use the Bitnami repository because the stable repository
  # is deprecated.
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"

  # Specify the exact version
  # so that the Helm terraform provider will know
  # when we want to upgrade.
  version = var.redis_chart_version

  # Use the storage class that we made above
  # for any persistent volumes that get provisioned.
  set {
    name  = "global.storageClass"
    value = module.csi.ebs_storage_class.metadata[0].name
  }

  # Disable cluster mode so that we only get a single
  # instance of redis.
  set {
    name  = "cluster.enabled"
    value = false
  }

  # Enable persistence for the master node.
  # Persistence is used by redis to preserve cached data
  # during temporary crashes.
  set {
    name  = "master.persistence.enabled"
    value = true
  }

  # Specify a 4 Gibibyte sized volume.
  set {
    name  = "master.persistence.size"
    value = "4Gi"
  }

  # Don't use password authentication
  set {
    name  = "usePassword"
    value = false
  }
}

# Install MongoDB into the cluster.
# MongoDB is used by CasualOS for permanent storage.
resource "helm_release" "mongodb" {
  name      = "mongodb"
  namespace = "default"

  # Use the Bitnami repository because the stable repository
  # is deprecated.
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "mongodb"

  # Specify the exact version
  # so that the Helm terraform provider will know
  # when we want to upgrade.
  version = var.mongodb_chart_version

  # Use the storage class that we made above
  # for any persistent volumes that get provisioned.
  set {
    name  = "global.storageClass"
    value = "ebs-sc-resizable"
  }

  # Enable replicating MongoDB for high availability.
  # We probably don't need this since CasualOS isn't currently setup
  # correctly for multiple MongoDB servers, but it doesn't hurt.
  set {
    name  = "replicaSet.enabled"
    value = true
  }

  # Set the replica set name to "rs0"
  set {
    name  = "replicaSet.name"
    value = "rs0"
  }

  # Specify 1 secondary replica.
  set {
    name  = "replicaSet.replicas.secondary"
    value = 1
  }

  # Specify 1 arbiter to help decide election results.
  set {
    name  = "replicaSet.replicas.arbiter"
    value = 1
  }

  # Enable pod disruption budget for MongoDB.
  # Pod disruption budgets are used by Kubernetes to
  # help it decide what to kill when faced with limited resources.
  set {
    name  = "replicaSet.pdb.enabled"
    value = true
  }

  # Specify that we have to have at least 1 secondary running
  # at all times.
  set {
    name  = "replicaSet.pdb.minAvailable.secondary"
    value = 1
  }

  # Specify that we need to have at least 1 arbiter running
  # at all times.
  set {
    name  = "replicaSet.pdb.minAvailable.arbiter"
    value = 1
  }

  # Enable persistence for the data storing pods.
  set {
    name  = "persistence.enabled"
    value = true
  }

  # Use volumes with at least 40 Gibibytes of space.
  set {
    name  = "persistence.size"
    value = "40Gi"
  }

  # Don't use a password to make login easy.
  # Also CasualOS currently doesn't support logging into MongoDB with a password.
  set {
    name  = "usePassword"
    value = false
  }
}

# Make a deployment for CasualOS.
# We don't have a Helm chart for CasualOS so we just make the needed
# resources here.
# Deployments tell Kubernetes to run X number of instances of a pod, but
# doesn't setup external access to the pod. That is what services and ingress are for.
resource "kubernetes_deployment" "casualos" {

  # Set the name to casualos
  metadata {
    name = "casualos"

    # Put it in the same namespace as Redis and MongoDB
    namespace = "default"

    # Also label it casualos so that the service can find it.
    labels = {
      app = "casualos"
    }
  }

  spec {
    # Only one replica for now since we don't support load
    # balancing due to the realtime connections.
    replicas = 1

    selector {
      match_labels = {
        app = "casualos"
      }
    }

    template {
      metadata {
        labels = {
          app = "casualos"
        }
      }

      spec {
        container {
          # Use the aux container from docker.
          image = "casualsimulation/aux:${var.casualos_version}"
          name  = "casualos"

          # Specify the sandbox type that
          # CasualOS needs - e.g. deno or use none.
          env {
            name  = "SANDBOX_TYPE"
            value = var.sandbox_type
          }
          
          # Specify debug state that
          # deno needs - e.g. true or use none.
          env {
            name  = "DEBUG"
            value = var.debug
          }

          # # Specify the sandbox type that
          # # CasualOS needs - e.g. deno or use none.
          # env {
          #   name  = "NODE_OPTIONS"
          #   value = var.node_options
          # }


          # Specify that port 3000 is the http port
          # Here, we give the port a name (http) that the service
          # can use to know where to send traffic.
          port {
            name           = "http"
            container_port = 3000
          }

          # Specify all the environment variables that
          # CasualOS needs.
          env {
            name  = "NODE_ENV"
            value = "production"
          }

          # Set the URL that CasualOS should use to connect to MongoDB.
          # See https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
          # for information on how Kubernetes DNS resolution works.
          env {
            name  = "MONGO_URL"
            value = "mongodb://mongodb.default:27017"
          }

          # Set the URL that CasualOS should use to connect to Redis.
          # See https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
          # for information on how Kubernetes DNS resolution works.
          env {
            name  = "REDIS_HOST"
            value = "redis-master.default"
          }

          # Specify the default Redis port
          env {
            name  = "REDIS_PORT"
            value = 6379
          }

          # Set some resource limits.
          # These ensure that CasualOS won't take up all the resources
          # if there is an issue.
          resources {
            limits {
              cpu    = "500m"
              memory = "2Gi"
            }

            # Tell Kubernetes that we want to start with 256MiB of ram reserved.
            requests {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          # Tell Kubernetes how to check CasualOS
          # to see if it is running correctly.
          # In this case, we're telling K8s to send a HTTP Get request
          # for the index path to port 3000. If it gets a valid response then the
          # container is running, otherwise it will record that the container has failed.
          # liveness_probe {
          #   http_get {
          #     path = "/"
          #     port = 3000
          #   }

          #   initial_delay_seconds = 3
          #   period_seconds        = 3
          # }
        }
      }
    }
  }
}

# Specify a service for CasualOS.
# Services in Kubernetes allow grouping a set of pods under a unique name.
# This makes it easier to coordinate pod communication since they can use DNS to resolve each other.
resource "kubernetes_service" "casualos" {
  metadata {
    # Specify that the name of the service is "casualos"
    name      = "casualos"
    namespace = "default"
  }
  spec {
    # Specify that this service targets all the pods
    # with the same app label as our casualos deployment.
    # (because the deployment creates pods with that label, they will be targeted by this service)
    selector = {
      app = kubernetes_deployment.casualos.metadata.0.labels.app
    }

    # Specify that the service should use port 80
    # but send traffic to the "http" port specified in the deployment.
    port {
      name = "http"
      port = 80

      # Use TCP instead of HTTP because it is faster
      # and we don't need any HTTP-level features.
      protocol    = "TCP"
      target_port = "http"
    }

    # Specify that this service should be assigned a Cluster-internal IP address.
    # This makes the service accessible from inside the cluster but not from outside.
    type = "ClusterIP"
  }
}

# Specify ingress for CasualOS.
# Ingress in Kubernetes define the act of allowing external traffic into the cluster
# for a particular service.
resource "kubernetes_ingress" "casualos" {

  # Depends on the ALB ingress controller being instantiated already.
  depends_on = [module.alb]

  metadata {
    name      = "casualos"
    namespace = "default"

    # AWS requires some annotations
    # to tell it how to configure the load balancer.
    # In this case, we're telling AWS to use an ALB (Application Load Balancer)
    # And to route traffic over the IP rules of our VPC.
    annotations = {
      "kubernetes.io/ingress.class"           = "alb"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"

      # Specify the ARN that should be used.
      "alb.ingress.kubernetes.io/certificate-arn" = var.certificate_arn

      # Listen on both HTTP port 80 and HTTPS port 443
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"

      # Setup a custom ingress action named "ssl-redirect" which 301 redirects from port 80 to port 443
      "alb.ingress.kubernetes.io/actions.ssl-redirect" = "{\"Type\": \"redirect\", \"RedirectConfig\": { \"Protocol\": \"HTTPS\", \"Port\": \"443\", \"StatusCode\": \"HTTP_301\"}}"
    }
  }

  spec {

    rule {
      http {

        # First try redirecting to port 443.
        # If this would cause an infinite loop, then Kubernetes will
        # decide to skip this first rule and go to the second.
        path {
          path = "/*"
          backend {
            # The service name is the same as the action we specified in the annotation.
            service_name = "ssl-redirect"
            service_port = "use-annotation"
          }
        }

        # Next, serve the CasualOS application
        path {
          path = "/*"
          backend {
            service_name = "casualos"
            service_port = "80"
          }
        }
      }
    }
  }
}
