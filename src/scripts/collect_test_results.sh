#!/bin/bash
# collect_test_results.sh -- Gather Surefire/Failsafe XML test reports.
# Searches for JUnit XML reports from Maven test phases and copies them
# to a central location for CircleCI test result parsing.
set -euo pipefail

DEST="/tmp/circleci/test-results"
mkdir -p "${DEST}"

echo "Collecting test results..."

# Find Surefire (unit) and Failsafe (integration) XML reports
find . -path "*/surefire-reports/*.xml" -o -path "*/failsafe-reports/*.xml" | while read -r file; do
  cp "${file}" "${DEST}/"
done

COUNT=$(find "${DEST}" -name "*.xml" 2>/dev/null | wc -l)
echo "Collected ${COUNT} test result files"
