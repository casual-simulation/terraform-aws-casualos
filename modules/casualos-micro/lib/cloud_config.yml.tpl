#cloud-config

write_files:
    - encoding: b64
      content: ${consul_server_config}
      owner: root:root
      path: /etc/consul-server.d/consul_config.hcl
      permissions: '0644'
    - encoding: b64
      content: ${consul_server_service}
      owner: root:root
      path: /etc/systemd/system/consul-server.service
    - encoding: b64
      content: ${consul_client_config}
      owner: root:root
      path: /etc/consul-client.d/consul_config.hcl
      permissions: '0644'
    - encoding: b64
      content: ${consul_client_service}
      owner: root:root
      path: /etc/systemd/system/consul-client.service

runcmd:
  - "sudo systemctl daemon-reload"
  - "sudo systemctl enable consul-server.service"
  - "sudo systemctl restart consul-server.service"
  - "sudo systemctl enable consul-client.service"
  - "sudo systemctl restart consul-client.service"