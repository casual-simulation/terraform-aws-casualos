[Unit]
Description="HashiCorp Nomad"
Documentation=https://www.nomadproject.io/
Requires=network-online.target
After=network-online.target
Wants=docker.service
ConditionDirectoryNotEmpty=/etc/nomad.d
StartLimitIntervalSec=10
StartLimitBurst=3

[Service]
# TODO: Re-enable when this issue is fixed:
# https://github.com/hashicorp/nomad/issues/7931
# User=nomad
# Group=nomad
ExecStart=/opt/nomad/bin/nomad agent -config /etc/nomad.d
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
TasksMax=infinity

[Install]
WantedBy=multi-user.target