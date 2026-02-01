#!/bin/bash
# node_build.sh -- Run the project's build command.
#
# Parameters (via environment):
#   PARAM_BUILD_COMMAND  Build command to execute (default: npm run build)
set -euo pipefail

BUILD_COMMAND="${PARAM_BUILD_COMMAND:-npm run build}"

echo "Running build: ${BUILD_COMMAND}"
eval "${BUILD_COMMAND}"
echo "Build complete"
