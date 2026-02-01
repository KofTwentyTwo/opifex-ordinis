#!/bin/bash
# node_install.sh -- Install npm dependencies using npm ci.
# Uses npm ci (clean install) for reproducible builds from package-lock.json.
# Cache restore/save is handled by the calling command YAML.
set -euo pipefail

echo "Installing npm dependencies..."
npm ci
echo "npm install complete"
