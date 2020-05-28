#!/bin/bash

set -e

sudo apt update

# Install redis-server
sudo apt install redis-server -y

# Edit the redis.conf file to tell it to run under systemd
sudo sed -i "s/^supervised no/supervised systemd/g" /etc/redis/redis.conf

# Tell Redis to bind to all IP Addresses
sudo sed -i "s/^[#\s]*bind 127.0.0.1 ::1/bind 0.0.0.0/g" /etc/redis/redis.conf

# Restart the redis service to pick up the config change
sudo systemctl restart redis.service