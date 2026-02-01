#!/bin/bash
# set_vite_build_mode.sh -- Set VITE_BUILD_MODE environment variable.
# When mode is "auto", maps the current branch to a Vite build mode:
#   - First deploy branch (typically main) -> "production"
#   - Other deploy branches -> branch name (e.g. develop, staging)
#   - Non-deploy branches -> "production"
# Any other value is used as-is.
#
# Parameters (via environment):
#   PARAM_MODE             Build mode value or "auto" for branch mapping
#   PARAM_DEPLOY_BRANCHES  Comma-separated deploy branches (for auto mode)
set -euo pipefail

MODE="${PARAM_MODE}"
DEPLOY_BRANCHES="${PARAM_DEPLOY_BRANCHES:-main}"

if [ "${MODE}" = "auto" ]; then
  IS_DEPLOY=false
  FIRST_BRANCH=""
  OIFS="${IFS}"; IFS=','
  for branch in ${DEPLOY_BRANCHES}; do
    branch_trimmed="${branch## }"
    branch_trimmed="${branch_trimmed%% }"
    if [ -z "${FIRST_BRANCH}" ]; then
      FIRST_BRANCH="${branch_trimmed}"
    fi
    if [ "${CIRCLE_BRANCH}" = "${branch_trimmed}" ]; then
      IS_DEPLOY=true
    fi
  done
  IFS="${OIFS}"

  if [ "${IS_DEPLOY}" = "true" ]; then
    if [ "${CIRCLE_BRANCH}" = "${FIRST_BRANCH}" ]; then
      MODE="production"
    else
      MODE="${CIRCLE_BRANCH}"
    fi
  else
    MODE="production"
  fi
fi

echo "export VITE_BUILD_MODE=${MODE}" >> "${BASH_ENV}"
echo "VITE_BUILD_MODE=${MODE}"
