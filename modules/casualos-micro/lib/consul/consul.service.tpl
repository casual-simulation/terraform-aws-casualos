[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionDirectoryNotEmpty=/etc/consul.d

[Service]
User=consul
Group=consul
Type=notify
ExecStart=/opt/consul/bin/consul agent -config-dir /etc/consul.d
ExecReload=/opt/consul/bin/consul reload
KillMode=process
Restart=on-failure
TimeoutSec=300s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target