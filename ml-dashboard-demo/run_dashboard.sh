#!/usr/bin/env bash
# Run the Streamlit dashboard on THIS checkout.
# Extra args pass straight through to streamlit, e.g. a second instance:
#   WT_VENV=../ml-dashboard-demo/.venv ./run_dashboard.sh --server.port 8502
set -euo pipefail
cd "$(dirname "$0")"

VENV="${WT_VENV:-.venv}"
[ -d "$VENV" ] || python3 -m venv "$VENV"
"$VENV/bin/python" -c "import streamlit, xgboost, plotly" 2>/dev/null \
  || "$VENV/bin/pip" install -q -r requirements.txt

exec "$VENV/bin/streamlit" run frontend/app.py "$@"
