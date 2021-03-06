
# A nomad job file that deploys a AWS EBS CSI plugin node on each machine
job "plugin-aws-ebs-nodes" {
  datacenters = ["${aws_region}"]

  # you can run node plugins as service jobs as well, but this ensures
  # that all nodes in the DC have a copy.
  type = "system"

  group "nodes" {

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
          "node",
          "--endpoint=unix://csi/csi.sock",
          "--logtostderr",
          "--v=5",
        ]

        # node plugins must run as privileged jobs because they
        # mount disks to the host
        privileged = true
      }

      csi_plugin {
        id        = "aws-ebs0"
        type      = "node"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 128
        memory = 64
      }
    }
  }
}
