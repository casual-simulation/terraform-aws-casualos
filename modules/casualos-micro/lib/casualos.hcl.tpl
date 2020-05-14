job "casualos" {

  datacenters = ["${aws_region}"]
  type = "service"

  group "auxPlayer" {
    count = 1

    restart {
      mode = "delay"
    }

    volume "mongodb" {
      type = "csi"
      read_only = false
      source = "mongodb"
    }

    task "mongo" {
      driver = "docker"

      config {
        image = "mongo:latest"
        port_map {
          mongodb = 27017
        }
      }

      volume_mount {
        volume = "mongodb"
        destination = "/data/db"
        read_only = false
      }

      resources {
        cpu    = 500 # 500 MHz
        memory = 441 # 441 MB

        network {
          port "mongodb" {
            static = 27017
          }
        }
      }

      service {
        name = "mongo"
        port = "mongodb"
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:latest"
        port_map {
          redis = 6379
        }
      }

      resources {
        cpu    = 256 # 256 MHz
        memory = 128 # 128 MB

        network {
          port "redis" {
            static = 6379
          }
        }
      }

      service {
        name = "redis"
        port = "redis"
      }
    }

    task "auxPlayer" {
      # The "driver" parameter specifies the task driver that should be used to
      # run the task.
      driver = "docker"

      # The "config" stanza specifies the driver configuration, which is passed
      # directly to the driver to start the task. The details of configurations
      # are specific to each driver, so please see specific driver
      # documentation for more information.
      config {
        image = "casualsimulation/aux:latest"
        port_map {
          http = 3000
        }
      }

      env {
        NODE_ENV = "production"
        MONGO_URL = "mongodb://mongo.service.consul:27017"
        REDIS_HOST = "redis.service.consul"
        REDIS_PORT = 6379
      }

      resources {
        cpu    = 500 # 500 MHz
        memory = 256 # 256MB

        network {
          port "http" {
            static = 3000
          }
        }
      }

      service {
        name = "auxPlayer"
        port = "http"
      }
    }
  }
}
