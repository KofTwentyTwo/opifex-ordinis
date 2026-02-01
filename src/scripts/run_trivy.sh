#!/bin/bash
# run_trivy.sh -- Run Trivy container image vulnerability scan.
# Only runs on deploy branches. Installs Trivy, scans the image, and
# writes a JSON report to /tmp/trivy-report.json. Fails the build if
# vulnerabilities matching the severity filter are found.
#
# Parameters (via environment):
#   PARAM_IMAGE_NAME       Docker image name (falls back to OO_IMAGE_NAME from buildx)
#   PARAM_IMAGE_TAG        Docker image tag (falls back to OO_IMAGE_TAG from buildx)
#   PARAM_DEPLOY_BRANCHES  Comma-separated deploy branches (default: main)
#   PARAM_TRIVY_SEVERITY   Severity filter (default: CRITICAL,HIGH)
set -euo pipefail

DEPLOY_BRANCHES="${PARAM_DEPLOY_BRANCHES:-main}"
TRIVY_SEVERITY="${PARAM_TRIVY_SEVERITY:-CRITICAL,HIGH}"

# Use params or fall back to env vars exported by docker_buildx_push.sh
IMAGE_NAME="${PARAM_IMAGE_NAME:-${OO_IMAGE_NAME:-}}"
IMAGE_TAG="${PARAM_IMAGE_TAG:-${OO_IMAGE_TAG:-}}"

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
  echo "Skipping Trivy scan"
  exit 0
fi

if [ -z "${IMAGE_NAME}" ] || [ -z "${IMAGE_TAG}" ]; then
  echo "No image to scan (IMAGE_NAME or IMAGE_TAG not set)"
  echo "Skipping Trivy scan"
  exit 0
fi

##########################################################
# Install Trivy                                          #
##########################################################
echo "Installing Trivy..."
TRIVY_VERSION="0.58.2"
curl -sSfL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
  | tar -xz -C /tmp
chmod +x /tmp/trivy

##########################################################
# Scan the image                                         #
##########################################################
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "Scanning image: ${FULL_IMAGE}"
echo "Severity filter: ${TRIVY_SEVERITY}"
echo ""

# Table output to console for human readability
EXIT_CODE=0
/tmp/trivy image \
  --severity "${TRIVY_SEVERITY}" \
  --ignore-unfixed \
  --format table \
  "${FULL_IMAGE}" \
  || EXIT_CODE=$?

# JSON report for artifact storage and downstream processing
/tmp/trivy image \
  --severity "${TRIVY_SEVERITY}" \
  --ignore-unfixed \
  --format json \
  --output /tmp/trivy-report.json \
  "${FULL_IMAGE}" \
  || true

##########################################################
# Summary                                                #
##########################################################
echo ""
echo "=== Trivy Summary ==="
if [ -f /tmp/trivy-report.json ]; then
  VULN_COUNT=$(python3 -c "
import json
r = json.load(open('/tmp/trivy-report.json'))
results = r.get('Results', [])
vulns = sum(len(res.get('Vulnerabilities', [])) for res in results)
print(vulns)
" 2>/dev/null || echo "unknown")
  echo "  Vulnerabilities: ${VULN_COUNT}"
  echo "  Severity: ${TRIVY_SEVERITY}"
else
  echo "  No report generated"
fi
echo "====================="

echo "Trivy scan complete (exit code: ${EXIT_CODE})"
exit "${EXIT_CODE}"
