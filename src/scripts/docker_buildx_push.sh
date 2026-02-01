#!/bin/bash
# docker_buildx_push.sh -- Build and push multi-arch Docker images via buildx + QEMU.
# Only runs on deploy branches. Sets up QEMU emulation, creates a buildx builder,
# authenticates to GHCR, and pushes a multi-platform image. Exports OO_IMAGE_NAME
# and OO_IMAGE_TAG to BASH_ENV for downstream steps (e.g., Trivy scanning).
#
# Parameters (via environment):
#   PARAM_IMAGE_NAME       Docker image name (default: ghcr.io/<org>/<repo>)
#   PARAM_IMAGE_TAG        Docker image tag (default: first 7 chars of CIRCLE_SHA1)
#   PARAM_DEPLOY_BRANCHES  Comma-separated deploy branches (default: main)
#   PARAM_PUSH_LATEST      Push latest tag on first deploy branch (default: true)
#   PARAM_DOCKER_PLATFORMS Buildx target platforms (default: linux/amd64,linux/arm64)
#
# Required environment variables (via CircleCI context):
#   GHCR_USERNAME  GitHub username
#   GHCR_TOKEN     GitHub personal access token with packages:write scope
#
# CircleCI environment variables (automatic):
#   CIRCLE_PROJECT_USERNAME  GitHub org/user
#   CIRCLE_PROJECT_REPONAME  Repository name
#   CIRCLE_SHA1              Full commit SHA
#   CIRCLE_BRANCH            Current branch name
#   BASH_ENV                 CircleCI env file for cross-step variable sharing
set -euo pipefail

DEPLOY_BRANCHES="${PARAM_DEPLOY_BRANCHES:-main}"
PUSH_LATEST="${PARAM_PUSH_LATEST:-true}"
DOCKER_PLATFORMS="${PARAM_DOCKER_PLATFORMS:-linux/amd64,linux/arm64}"

# Resolve image name -- default to ghcr.io/<org>/<repo> (lowercased)
IMAGE_NAME="${PARAM_IMAGE_NAME:-}"
if [ -z "${IMAGE_NAME}" ]; then
  OWNER=$(echo "${CIRCLE_PROJECT_USERNAME}" | tr '[:upper:]' '[:lower:]')
  REPO=$(echo "${CIRCLE_PROJECT_REPONAME}" | tr '[:upper:]' '[:lower:]')
  IMAGE_NAME="ghcr.io/${OWNER}/${REPO}"
fi

# Resolve image tag -- default to short SHA
IMAGE_TAG="${PARAM_IMAGE_TAG:-}"
if [ -z "${IMAGE_TAG}" ]; then
  IMAGE_TAG="${CIRCLE_SHA1:0:7}"
fi

# Export for downstream steps (e.g., Trivy scanning)
echo "export OO_IMAGE_NAME=${IMAGE_NAME}" >> "${BASH_ENV}"
echo "export OO_IMAGE_TAG=${IMAGE_TAG}" >> "${BASH_ENV}"

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

is_first_deploy_branch() {
  FIRST=$(echo "${DEPLOY_BRANCHES}" | cut -d',' -f1 | tr -d ' ')
  [ "${CIRCLE_BRANCH}" = "${FIRST}" ]
}

if ! is_deploy_branch; then
  echo "Branch '${CIRCLE_BRANCH}' is not a deploy branch (${DEPLOY_BRANCHES})"
  echo "Skipping Docker build + push"
  exit 0
fi

##########################################################
# Setup QEMU + buildx                                    #
##########################################################
echo "Setting up QEMU for multi-arch builds..."
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

echo "Creating buildx builder..."
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap

##########################################################
# GHCR login                                             #
##########################################################
if [ -z "${GHCR_TOKEN:-}" ] || [ -z "${GHCR_USERNAME:-}" ]; then
  echo "GHCR_TOKEN and GHCR_USERNAME must be set (via context)"
  exit 1
fi
echo "${GHCR_TOKEN}" | docker login ghcr.io -u "${GHCR_USERNAME}" --password-stdin

##########################################################
# Build tag list                                         #
##########################################################
TAGS="-t ${IMAGE_NAME}:${IMAGE_TAG}"

# Tag with branch name on all deploy branches (e.g., :develop, :staging)
TAGS="${TAGS} -t ${IMAGE_NAME}:${CIRCLE_BRANCH}"

# Push :latest only on the first listed deploy branch
if [ "${PUSH_LATEST}" = "true" ] && is_first_deploy_branch; then
  TAGS="${TAGS} -t ${IMAGE_NAME}:latest"
fi

##########################################################
# Build + push                                           #
##########################################################
echo ""
echo "Building multi-arch image..."
echo "  Image:     ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  Platforms: ${DOCKER_PLATFORMS}"
echo ""

# shellcheck disable=SC2086
docker buildx build \
  --platform "${DOCKER_PLATFORMS}" \
  ${TAGS} \
  --push \
  .

echo ""
echo "Docker build + push complete"
echo "  ${IMAGE_NAME}:${IMAGE_TAG}"
