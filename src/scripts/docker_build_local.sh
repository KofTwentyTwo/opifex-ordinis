#!/bin/bash
# docker_build_local.sh -- Build a local Docker image for pre-publish scanning.
# Only runs on deploy branches. Builds a single-arch image locally
# (no push) so security tools like Trivy can scan it before the
# multi-arch publish step.
#
# Parameters (via environment):
#   PARAM_IMAGE_NAME       Docker image name (falls back to GHCR convention)
#   PARAM_IMAGE_TAG        Docker image tag (falls back to short SHA)
#   PARAM_DEPLOY_BRANCHES  Comma-separated deploy branches
set -euo pipefail

DEPLOY_BRANCHES="${PARAM_DEPLOY_BRANCHES:-main}"

##########################################################
# Check if current branch is a deploy branch             #
##########################################################
is_deploy_branch() {
  IFS=',' read -ra BRANCHES <<< "${DEPLOY_BRANCHES}"
  for branch in "${BRANCHES[@]}"; do
    if [ "${CIRCLE_BRANCH}" = "${branch// /}" ]; then
      return 0
    fi
  done
  return 1
}

if ! is_deploy_branch; then
  echo "Branch '${CIRCLE_BRANCH}' is not a deploy branch (${DEPLOY_BRANCHES})"
  echo "Skipping local Docker build"
  exit 0
fi

##########################################################
# Build local image                                      #
##########################################################
IMAGE_NAME="${PARAM_IMAGE_NAME:-ghcr.io/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}}"
IMAGE_TAG="${PARAM_IMAGE_TAG:-${CIRCLE_SHA1:0:7}}"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

echo "Building local image for scanning: ${FULL_IMAGE}"
docker build -t "${FULL_IMAGE}" .

##########################################################
# Export image info for downstream steps (Trivy, etc.)   #
##########################################################
echo "export OO_IMAGE_NAME='${IMAGE_NAME}'" >> "${BASH_ENV}"
echo "export OO_IMAGE_TAG='${IMAGE_TAG}'" >> "${BASH_ENV}"
echo "Local image built: ${FULL_IMAGE}"
