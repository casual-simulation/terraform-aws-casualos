#cloud-config

write_files:
    - encoding: b64
      content: ${consul_config}
      owner: root:root
      path: /etc/consul.d/consul_config.hcl
      permissions: '0644'
    - encoding: b64
      content: ${consul_service}
      owner: root:root
      path: /etc/systemd/system/consul.service

runcmd:
  - "sudo systemctl daemon-reload"
  - "sudo systemctl enable consul.service"
  - "sudo systemctl restart consul.service"