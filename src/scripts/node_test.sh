#!/bin/bash
# node_test.sh -- Run the project's test command.
# Playwright browser installation is handled by the calling command YAML.
#
# Parameters (via environment):
#   PARAM_TEST_COMMAND  Test command to execute (default: npm test)
set -euo pipefail

TEST_COMMAND="${PARAM_TEST_COMMAND:-npm test}"

echo "Running tests: ${TEST_COMMAND}"
eval "${TEST_COMMAND}"
echo "Tests complete"
