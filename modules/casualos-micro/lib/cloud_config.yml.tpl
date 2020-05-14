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

      # Create a config file so that we can use the AWS command line
      # in scripts
    - path: /home/ubuntu/.aws/config
      content: |
        [default]
        credential_source = Ec2InstanceMetadata
      permissions: '0644'

      # Create a file that bootstraps the ACL and puts the token on AWS Secrets Manager
    - path: /home/ubuntu/bootstrap.sh
      content: |
        #!/bin/bash

        if [[ -z "${zerotier_network}" ]]; then
          echo "No ZeroTier network specified. Skipping join."
        else
          echo "Joining ZeroTier network..."
          sudo zerotier-cli join "${zerotier_network}"

          if [[ -z "${zerotier_api_key}" ]]; then
            echo "No ZeroTier API Key. Skipping authorization."
          else
            echo "Authorizing to network..."
            sleep 5
            NODE_ID=$(sudo zerotier-cli info | awk '{print $3}')
            NODE_NAME=$(ec2metadata --instance-id)
            curl -X POST \
                 -H 'Authorization: Bearer ${zerotier_api_key}' \
                 -d "{\"config\":{\"authorized\":true},\"name\":\"$NODE_NAME\"}" \
                 "https://my.zerotier.com/api/network/${zerotier_network}/member/$NODE_ID"
          fi
          echo "Done."
        fi
      permissions: '0111' # Execute only
runcmd:
  - "sudo systemctl daemon-reload"
  - "sudo systemctl enable consul.service"
  - "sudo systemctl restart consul.service"
  - "sudo systemctl enable nomad.service"
  - "sudo systemctl restart nomad.service"
  - "/home/ubuntu/bootstrap.sh"