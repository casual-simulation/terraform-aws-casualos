
// Boot as both a server and a client
server {
 enabled = true
 bootstrap_expect = 1
}

client {
  enabled = true
}

// Expect to be the only server in the cluster
datacenter = "${aws_region}"
bind_addr  = "0.0.0.0"
data_dir = "/opt/nomad/data"

consul {
  address = "127.0.0.1:8500"
}

acl {
  enabled = true
}

plugin "docker" {
  config {
    allow_privileged = true
  }
}
