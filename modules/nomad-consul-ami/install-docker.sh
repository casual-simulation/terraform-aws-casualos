#!/bin/bash

set -e

# Fallback to apt if apt-get fails
sudo apt-get update || sudo apt update -y
sudo apt-get upgrade -y

# Install utilities that Docker needs
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

# Install Docker
sudo apt install -y docker.io

# Add the ubuntu user to the docker group
sudo usermod -a -G docker ubuntu