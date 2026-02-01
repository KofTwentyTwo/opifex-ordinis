#!/bin/bash
# collect_security_reports.sh -- Aggregate security scan reports for artifact storage.
# Copies Gitleaks, Trivy, and OWASP reports from /tmp into a single directory
# at /tmp/circleci/security-reports for CircleCI store_artifacts.
set -euo pipefail

DEST="/tmp/circleci/security-reports"
mkdir -p "${DEST}"

echo "Collecting security reports..."

# Gitleaks
if [ -f /tmp/gitleaks-report.json ]; then
  cp /tmp/gitleaks-report.json "${DEST}/"
  echo "  Collected: gitleaks-report.json"
fi

# Trivy
if [ -f /tmp/trivy-report.json ]; then
  cp /tmp/trivy-report.json "${DEST}/"
  echo "  Collected: trivy-report.json"
fi

# OWASP
if [ -f /tmp/owasp-dependency-check.json ]; then
  cp /tmp/owasp-dependency-check.json "${DEST}/"
  echo "  Collected: owasp-dependency-check.json"
fi
if [ -f /tmp/owasp-dependency-check.html ]; then
  cp /tmp/owasp-dependency-check.html "${DEST}/"
  echo "  Collected: owasp-dependency-check.html"
fi

echo "Security report collection complete"
