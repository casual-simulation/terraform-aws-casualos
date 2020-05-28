#!/bin/bash

set -e

curl -s https://install.zerotier.com | sudo bash

# Clear the ZeroTier Node ID from the AMI
sudo service zerotier-one stop
sudo rm /var/lib/zerotier-one/identity.public
sudo rm /var/lib/zerotier-one/identity.secret

# Leave ZeroTier stopped. It will be automatically started by systemd on new systems.