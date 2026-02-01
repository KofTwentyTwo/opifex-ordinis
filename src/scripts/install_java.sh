#!/bin/bash
# install_java.sh -- Install Eclipse Temurin JDK + Maven on the machine executor.
# Optionally installs Node.js for fullstack projects with a frontend build step.
#
# Parameters (via environment):
#   PARAM_JAVA_VERSION   Temurin JDK version (default: 21)
#   PARAM_INSTALL_NODE   Install Node.js alongside Java (default: false)
#   PARAM_NODE_VERSION   Node.js major version if enabled (default: 22)
set -euo pipefail

JAVA_VERSION="${PARAM_JAVA_VERSION:-21}"
INSTALL_NODE="${PARAM_INSTALL_NODE:-false}"
NODE_VERSION="${PARAM_NODE_VERSION:-22}"

echo "Installing Java ${JAVA_VERSION} and Maven..."

# Install prerequisites
sudo apt-get update -qq
sudo apt-get install -y -qq wget apt-transport-https gpg maven curl

# Add Temurin GPG key + repository
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
  | sudo gpg --dearmor -o /usr/share/keyrings/adoptium.gpg

echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/adoptium.list

# Install JDK
sudo apt-get update -qq
sudo apt-get install -y -qq "temurin-${JAVA_VERSION}-jdk"

# Set JAVA_HOME for subsequent steps
JAVA_HOME="/usr/lib/jvm/temurin-${JAVA_VERSION}-jdk-amd64"
echo "export JAVA_HOME=${JAVA_HOME}" >> "${BASH_ENV}"
echo "export PATH=${JAVA_HOME}/bin:\$PATH" >> "${BASH_ENV}"

# Optional Node.js for fullstack Maven projects (e.g., frontend-maven-plugin)
if [ "${INSTALL_NODE}" = "true" ]; then
  echo ""
  echo "Installing Node.js ${NODE_VERSION}..."
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | sudo -E bash -
  sudo apt-get install -y -qq nodejs
  echo "Node.js: $(node --version)"
  echo "npm: $(npm --version)"
fi

echo ""
echo "Java: $(java -version 2>&1 | head -1)"
echo "Maven: $(mvn --version | head -1)"
echo "Installation complete"
