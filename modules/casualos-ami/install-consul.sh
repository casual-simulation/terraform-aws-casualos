#!/bin/bash

set -e

sudo chmod +x /tmp/install-consul.sh
/tmp/install-consul.sh --version "${CONSUL_VERSION}"

# Let Consul bind to port 53
sudo setcap 'cap_net_bind_service=+ep' /opt/consul/bin/consul