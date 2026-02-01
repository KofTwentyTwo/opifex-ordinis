#!/bin/bash
# docker_login_ghcr.sh -- Authenticate to GitHub Container Registry.
# Standalone command for custom workflows. The docker_buildx_push script
# handles its own GHCR login internally.
#
# Required environment variables (via CircleCI context):
#   GHCR_USERNAME  GitHub username
#   GHCR_TOKEN     GitHub personal access token with packages:write scope
set -euo pipefail

echo "Logging in to GitHub Container Registry..."

if [ -z "${GHCR_TOKEN:-}" ] || [ -z "${GHCR_USERNAME:-}" ]; then
  echo "GHCR_TOKEN and GHCR_USERNAME must be set (via context)"
  exit 1
fi

echo "${GHCR_TOKEN}" | docker login ghcr.io -u "${GHCR_USERNAME}" --password-stdin
echo "GHCR login successful"
