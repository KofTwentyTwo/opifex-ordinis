#!/bin/bash
# checkout_full.sh -- Fetch full git history and tags after CircleCI checkout.
# CircleCI's built-in checkout is shallow; this ensures tags are available
# for version calculation and Docker image tagging.
set -euo pipefail

echo "Fetching full history and tags..."
git fetch --tags --force
echo "Checkout complete"
