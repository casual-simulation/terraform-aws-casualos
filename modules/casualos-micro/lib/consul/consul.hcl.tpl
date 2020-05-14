
// Boot as a server
server = true

data_dir = "/opt/consul/data"

// Expect to be the only server in the cluster
bootstrap_expect = 1
datacenter = "${aws_region}"

// Set the Bind Address to use the interface that has an ip for the 10.0.x.x IP Address block.
// (The AWS VPC)
bind_addr = "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/16\" | attr \"address\" }}"

// TODO: Specify a go-sockaddr template for these
// advertise_addr = "$$instance_ip_address",
// bind_addr = "$$instance_ip_address",
// client_addr = "0.0.0.0"

// TODO: Setup UI
ui = false

// TODO: Configure Autopilot
// autopilot {
//   cleanup_dead_servers = $${cleanup_dead_servers}
//   last_contact_threshold = $${last_contact_threshold}
//   max_trailing_logs = $${max_trailing_logs}
//   server_stabilization_time = $${server_stabilization_time}
//   redundancy_zone_tag = $${redundancy_zone_tag}
//   disable_upgrade_migration = $${disable_upgrade_migration}
//   upgrade_version_tag = $${upgrade_version_tag}
// }

// TODO: Setup gossip traffic encryption
// encrypt = $${gossip_encryption_key}

// TODO: Setup RPC Encryption
// verify_outgoing = true
// verify_incoming = true
// ca_path = $${ca_path}
// cert_file = $${cert_file_path}
// key_file = $${key_file_path}
