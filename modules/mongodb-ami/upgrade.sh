#!/bin/bash

set -e

# Update and upgrade everything
sudo apt-get update || sudo apt update -y
sudo apt-get upgrade -y