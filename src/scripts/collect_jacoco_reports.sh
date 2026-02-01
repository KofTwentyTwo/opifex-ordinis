#!/bin/bash
# collect_jacoco_reports.sh -- Gather JaCoCo HTML coverage reports from all modules.
# Searches for target/site/jacoco directories and copies them to a central
# location for CircleCI artifact storage.
set -euo pipefail

DEST="/tmp/circleci/jacoco"
mkdir -p "${DEST}"

echo "Collecting JaCoCo reports..."

# Find all JaCoCo HTML report directories across Maven modules
find . -path "*/site/jacoco" -type d | while read -r dir; do
  MODULE=$(echo "${dir}" | sed 's|^\./||;s|/target/.*||')
  if [ -d "${dir}" ]; then
    cp -r "${dir}" "${DEST}/${MODULE//\//-}"
    echo "  Collected: ${MODULE}"
  fi
done

echo "JaCoCo collection complete"
