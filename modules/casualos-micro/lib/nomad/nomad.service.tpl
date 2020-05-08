[Unit]
Description="HashiCorp Nomad"
Documentation=https://www.nomadproject.io/
Requires=network-online.target
After=network-online.target
Wants=docker.service
ConditionDirectoryNotEmpty=/etc/nomad.d

[Service]
User=nomad
Group=nomad
ExecStart=/opt/nomad/bin/nomad agent -config /etc/nomad.d
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target