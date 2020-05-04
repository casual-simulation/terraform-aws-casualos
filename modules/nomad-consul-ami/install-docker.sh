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

# Download and install the Docker repository GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add the Docker repository
# TODO: Support ARM64
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# Install Docker
sudo apt-get update || sudo apt update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Add the ubuntu user to the docker group
sudo usermod -a -G docker ubuntu