#!/bin/bash
# setup_maven_settings.sh -- Generate Maven settings.xml for CI builds.
# Creates a settings file at /tmp/circleci/mvn-settings.xml with GitHub
# Packages server credentials sourced from environment variables.
#
# Required environment variables (via CircleCI context):
#   GITHUB_USERNAME  GitHub username for Maven repository access
#   GITHUB_TOKEN     GitHub token for Maven repository access
set -euo pipefail

SETTINGS_DIR="/tmp/circleci"
SETTINGS_FILE="${SETTINGS_DIR}/mvn-settings.xml"

echo "Generating Maven settings.xml..."

mkdir -p "${SETTINGS_DIR}"

cat > "${SETTINGS_FILE}" << 'SETTINGS_EOF'
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <servers>
    <server>
      <id>github</id>
      <username>${env.GITHUB_USERNAME}</username>
      <password>${env.GITHUB_TOKEN}</password>
    </server>
  </servers>
</settings>
SETTINGS_EOF

echo "Maven settings written to ${SETTINGS_FILE}"
