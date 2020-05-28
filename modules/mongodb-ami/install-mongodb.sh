#!/bin/bash

set -e

# Add the MongoDB repository key
wget -qO - https://www.mongodb.org/static/pgp/server-4.2.asc | sudo apt-key add -

# Add the MongoDB repository
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.2.list

# Update Repository lists
sudo apt-get update || sudo apt update -y

# Install MongoDB
sudo apt-get install -y mongodb-org || sudo apt install -y mongodb-org