#!/usr/bin/env bash
# Train the model on THIS checkout (the demo's long-running job in tuned mode).
#
# Set WT_VENV to reuse an existing virtualenv (e.g. the main checkout's .venv)
# so a worktree doesn't have to reinstall xgboost/optuna just to run.
#   WT_VENV=../ml-dashboard-demo/.venv ./run_train.sh --mode baseline
set -euo pipefail
cd "$(dirname "$0")"

VENV="${WT_VENV:-.venv}"
[ -d "$VENV" ] || python3 -m venv "$VENV"
"$VENV/bin/python" -c "import xgboost, optuna" 2>/dev/null \
  || "$VENV/bin/pip" install -q -r requirements.txt

exec "$VENV/bin/python" -m backend.train "$@"
