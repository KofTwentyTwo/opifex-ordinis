#!/bin/bash
# install_node.sh -- Install Node.js on the machine executor via NodeSource.
#
# Parameters (via environment):
#   PARAM_NODE_VERSION  Node.js major version (default: 22)
set -euo pipefail

NODE_VERSION="${PARAM_NODE_VERSION:-22}"

echo "Installing Node.js ${NODE_VERSION}..."

curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | sudo -E bash -
sudo apt-get install -y -qq nodejs

echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"
echo "Node.js installation complete"
