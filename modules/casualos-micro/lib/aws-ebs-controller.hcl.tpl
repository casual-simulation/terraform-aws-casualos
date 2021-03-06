
# A nomad job to run the AWS EBS CSI plugin controller
# See https://learn.hashicorp.com/nomad/stateful-workloads/csi-volumes
job "plugin-aws-ebs-controller" {
  datacenters = ["${aws_region}"]

  group "controller" {

    restart {
      attempts = 5
      delay = "1m"
      interval = "10m"
      mode = "delay"
    }

    task "plugin" {
      driver = "docker"

      config {
        image = "amazon/aws-ebs-csi-driver:latest"

        args = [
          "controller",
          "--endpoint=unix://csi/csi.sock",
          "--logtostderr",
          "--v=5",
        ]
      }

      csi_plugin {
        id        = "aws-ebs0"
        type      = "controller"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 128
        memory = 64
      }
    }
  }
}
