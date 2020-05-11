job "casualos" {

  datacenters = ["${aws_region}"]
  type = "service"

  group "auxPlayer" {
    count = 1

    task "mongo" {
      driver = "docker"

      config {
        image = "mongo:latest"
        port_map {
          mongodb = 27017
        }

        mounts = [
          {
            type = "volume"
            target = "/data/db"
            source = "mongodb"
            readonly = false
          }
        ]
      }

      resources {
        cpu    = 500 # 500 MHz
        memory = 512 # 512 MB
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

        mounts = [
          {
            type = "volume"
            target = "/data"
            source = "redis"
            readonly = false
          }
        ]
      }

      resources {
        cpu    = 256 # 256 MHz
        memory = 256 # 256 MB
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
          websocket = 4567
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
      }

      service {
        name = "auxPlayer"
        port = "http"
      }
    }
  }
}
