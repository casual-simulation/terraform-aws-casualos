#cloud-config

write_files:
    - encoding: b64
      content: ${consul_config}
      owner: consul:consul
      path: /etc/consul.d/consul_config.hcl
      permissions: '0644'
    - encoding: b64
      content: ${consul_service}
      owner: root:root
      path: /etc/systemd/system/consul.service
    - encoding: b64
      content: ${nomad_config}
      owner: nomad:nomad
      path: /etc/nomad.d/nomad_config.hcl
      permissions: '0644'
    - encoding: b64
      content: ${nomad_service}
      owner: root:root
      path: /etc/systemd/system/nomad.service

runcmd:
  - "sudo systemctl daemon-reload"
  - "sudo systemctl enable consul.service"
  - "sudo systemctl restart consul.service"
  - "sudo systemctl enable nomad.service"
  - "sudo systemctl restart nomad.service"