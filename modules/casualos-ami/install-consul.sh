#!/bin/bash

set -e

sudo chmod +x /tmp/install-consul.sh
/tmp/install-consul.sh --version "${CONSUL_VERSION}"

# Setup DNS

sudo mkdir -p /etc/systemd/resolved.conf.d

# Set resolved.conf to use localhost for name resolution
sudo cat > /etc/systemd/resolved.conf.d/consul.conf <<- EOM
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.
#
# Entries in this file show the compile time defaults.
# You can change settings by editing this file.
# Defaults can be restored by simply deleting this file.
#
# See resolved.conf(5) for details

[Resolve]
DNS=127.0.0.1
FallbackDNS=127.0.0.53
Domains=~consul
EOM

# Set the iptables to redirect queries for port 53 (DNS) to port 8600 (consul)
sudo iptables -t nat -A OUTPUT -d localhost -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600
sudo iptables -t nat -A OUTPUT -d localhost -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600

# Restart the resolver service
sudo service systemd-resolved restart