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

        # NEXT_WAIT_TIME=0
        # ATTEMPTS=0
        # MAX_ATTEMPTS=20
        # until [ $ATTEMPTS -eq $MAX_ATTEMPTS ] || curl -o /home/ubuntu/bootstrap_token.json --request POST http://127.0.0.1:4646/v1/acl/bootstrap; do
        #   ATTEMPTS=$((ATTEMPTS + 1))
        #   NEXT_WAIT_TIME=$((NEXT_WAIT_TIME + 1))
        #   echo "Request failed! Trying again in $NEXT_WAIT_TIME seconds..."
        #   sleep $NEXT_WAIT_TIME
        # done
        # if [ $ATTEMPTS -ge $MAX_ATTEMPTS ];
        # then
        #   echo "Unable to bootstrap."
        #   exit 1;
        # fi
        # AWS_REGION=$(ec2metadata --availability-zone | sed -e 's:\([0-9][0-9]*\)[a-z]*$:\1:')
        # aws secretsmanager put-secret-value --region "$AWS_REGION" --secret-id "casualos/nomad/BootstrapToken" --secret-string "$(cat /home/ubuntu/bootstrap_token.json)"
      permissions: '0111' # Execute only
runcmd:
  - "sudo systemctl daemon-reload"
  - "sudo systemctl enable consul.service"
  - "sudo systemctl restart consul.service"
  - "sudo systemctl enable nomad.service"
  - "sudo systemctl restart nomad.service"
  - "/home/ubuntu/bootstrap.sh"