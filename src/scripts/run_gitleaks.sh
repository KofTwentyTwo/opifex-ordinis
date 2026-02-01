#!/bin/bash
# run_gitleaks.sh -- Run Gitleaks secret detection scan.
# Installs Gitleaks, scans the repository for hardcoded secrets, and writes
# a JSON report to /tmp/gitleaks-report.json. Runs on all branches.
# Fails the build if secrets are found. Use .gitleaks.toml to allowlist
# known safe patterns (e.g. local dev credentials).
set -euo pipefail

echo "Running Gitleaks secret detection..."

##########################################################
# Install Gitleaks                                       #
##########################################################
GITLEAKS_VERSION="8.21.2"
curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
  | tar -xz -C /tmp
chmod +x /tmp/gitleaks

##########################################################
# Run scan                                               #
##########################################################
EXIT_CODE=0
/tmp/gitleaks detect \
  --source=. \
  --report-format=json \
  --report-path=/tmp/gitleaks-report.json \
  --verbose \
  || EXIT_CODE=$?

##########################################################
# Summary                                                #
##########################################################
echo ""
echo "=== Gitleaks Summary ==="
if [ -f /tmp/gitleaks-report.json ]; then
  COUNT=$(python3 -c "import json; print(len(json.load(open('/tmp/gitleaks-report.json'))))" 2>/dev/null || echo "unknown")
  echo "  Findings: ${COUNT}"
else
  echo "  Findings: 0"
fi
echo "========================="

echo "Gitleaks scan complete (exit code: ${EXIT_CODE})"
exit "${EXIT_CODE}"
