#!/bin/bash
# run_owasp_dependency_check.sh -- Run OWASP Dependency-Check for Maven projects.
# Scans project dependencies against the NVD database for known CVEs. Retries
# up to 3 times to handle intermittent NVD download failures. Writes JSON and
# HTML reports to /tmp for artifact collection.
#
# Optional environment variables (via CircleCI context):
#   NVD_API_KEY           NVD API key for faster database updates
#   OWASP_CVSS_THRESHOLD  CVSS score threshold to fail build (default: 7)
set -euo pipefail

echo "Running OWASP Dependency-Check..."

OWASP_CVSS_THRESHOLD="${OWASP_CVSS_THRESHOLD:-7}"

##########################################################
# Build Maven command                                    #
##########################################################
MVN_CMD="mvn -s /tmp/circleci/mvn-settings.xml --no-transfer-progress"
MVN_CMD="${MVN_CMD} org.owasp:dependency-check-maven:12.1.0:aggregate"
MVN_CMD="${MVN_CMD} -DskipTests"
MVN_CMD="${MVN_CMD} -DfailBuildOnCVSS=${OWASP_CVSS_THRESHOLD}"
MVN_CMD="${MVN_CMD} -Dformats=JSON,HTML"
MVN_CMD="${MVN_CMD} -DdataDirectory=${HOME}/.owasp/data"
MVN_CMD="${MVN_CMD} -DossindexAnalyzerEnabled=false"

if [ -n "${NVD_API_KEY:-}" ]; then
  MVN_CMD="${MVN_CMD} -DnvdApiKey=${NVD_API_KEY}"
  echo "  NVD API key detected"
else
  echo "  No NVD API key -- unauthenticated access (slower)"
fi

# Auto-detect suppression file
if [ -f "dependency-check-suppressions.xml" ]; then
  MVN_CMD="${MVN_CMD} -DsuppressionFile=dependency-check-suppressions.xml"
  echo "  Suppression file detected"
fi

##########################################################
# Run with retry logic (3 attempts)                      #
##########################################################
MAX_RETRIES=3
ATTEMPT=1
EXIT_CODE=0

while [ "${ATTEMPT}" -le "${MAX_RETRIES}" ]; do
  echo ""
  echo "OWASP Dependency-Check attempt ${ATTEMPT}/${MAX_RETRIES}..."

  EXIT_CODE=0
  eval "${MVN_CMD}" 2>&1 | tee /tmp/owasp-output.txt || EXIT_CODE=$?

  # Exit code 0 = clean, 1 = vulnerabilities found (expected); anything else = tool error
  if [ "${EXIT_CODE}" -eq 0 ] || [ "${EXIT_CODE}" -eq 1 ]; then
    break
  fi

  echo "Attempt ${ATTEMPT} failed (exit code ${EXIT_CODE})"
  ATTEMPT=$((ATTEMPT + 1))

  if [ "${ATTEMPT}" -le "${MAX_RETRIES}" ]; then
    echo "Retrying in 30 seconds..."
    sleep 30
  fi
done

if [ "${ATTEMPT}" -gt "${MAX_RETRIES}" ] && [ "${EXIT_CODE}" -gt 1 ]; then
  echo "OWASP Dependency-Check failed after ${MAX_RETRIES} attempts"
  exit 1
fi

##########################################################
# Collect reports                                        #
##########################################################
REPORT_FILE=$(find . -name "dependency-check-report.json" -path "*/target/*" | head -1)
if [ -n "${REPORT_FILE}" ]; then
  cp "${REPORT_FILE}" /tmp/owasp-dependency-check.json
fi

HTML_REPORT=$(find . -name "dependency-check-report.html" -path "*/target/*" | head -1)
if [ -n "${HTML_REPORT}" ]; then
  cp "${HTML_REPORT}" /tmp/owasp-dependency-check.html
fi

##########################################################
# Summary                                                #
##########################################################
echo ""
echo "=== OWASP Dependency-Check Summary ==="
if [ -f /tmp/owasp-dependency-check.json ]; then
  VULN_COUNT=$(python3 -c "
import json
r = json.load(open('/tmp/owasp-dependency-check.json'))
deps = r.get('dependencies', [])
vulns = sum(len(d.get('vulnerabilities', [])) for d in deps)
print(vulns)
" 2>/dev/null || echo "unknown")
  echo "  Vulnerabilities: ${VULN_COUNT}"
  echo "  CVSS Threshold: ${OWASP_CVSS_THRESHOLD}"
else
  echo "  No report generated"
fi
echo "======================================="

echo "OWASP Dependency-Check complete (exit code: ${EXIT_CODE})"
exit "${EXIT_CODE}"
