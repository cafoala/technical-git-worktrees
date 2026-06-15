#!/usr/bin/env bash
#
# build-bundle.sh — turn the real source tree in ./ml-dashboard-demo/ into a
# git repo with a shaped history, then pack it into ml-dashboard-demo.bundle.
#
# This is the ONLY place that knows the demo's git topology. The project itself
# is just normal files in ml-dashboard-demo/ — browse/edit them like any repo,
# then re-run this to regenerate the bundle.
#
# Shaped history (all commits are additive — no per-commit file variants):
#   1. scaffold
#   2. data layer + its test
#   3. model + train + run_train.sh + test     -> tag v1.0  (baseline only)
#   4. dashboard (frontend + theme + run script)
#   5. Optuna Bayesian tuning  (main's improvement over v1.0; the long job)
#   6. notebooks
#   branch feature/whatif-predictor  (colleague's unmerged panel)
#
# Run:  bash build-bundle.sh        then  bash unpack-demo.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/ml-dashboard-demo"
BUNDLE="$HERE/ml-dashboard-demo.bundle"
BUILD="$(mktemp -d "${TMPDIR:-/tmp}/ml-dashboard-build.XXXXXX")"

trap 'rm -rf "$BUILD"' EXIT

say() { printf '\033[1;36m==>\033[0m %s\n' "$1"; }

[ -d "$SRC" ] || { echo "source tree not found: $SRC" >&2; exit 1; }

# ---------------------------------------------------------------------------
# init the build repo
# ---------------------------------------------------------------------------
say "Building shaped history in $BUILD"
git init -q "$BUILD"
git -C "$BUILD" symbolic-ref HEAD refs/heads/main
git -C "$BUILD" config user.name  "Demo Author"
git -C "$BUILD" config user.email "demo-author@example.com"
git -C "$BUILD" config commit.gpgsign false 2>/dev/null || true

# copy path(s) from SRC into BUILD, preserving directory structure
copy() {
  local f
  for f in "$@"; do
    mkdir -p "$BUILD/$(dirname "$f")"
    cp "$SRC/$f" "$BUILD/$f"
  done
}
commit() { git -C "$BUILD" add -A && git -C "$BUILD" commit -q -m "$1"; }

# ---------------------------------------------------------------------------
# 1. scaffold
# ---------------------------------------------------------------------------
say "Commit 1/6: scaffold"
copy README.md requirements.txt .gitignore Makefile conftest.py \
     .streamlit/config.toml backend/__init__.py frontend/__init__.py
commit "chore: project scaffold (package layout, requirements, streamlit theme)"

# ---------------------------------------------------------------------------
# 2. data layer
# ---------------------------------------------------------------------------
say "Commit 2/6: data layer"
copy backend/data.py tests/test_data.py
commit "feat: load California housing + engineer features"

# ---------------------------------------------------------------------------
# 3. model + baseline trainer  -> tag v1.0
# ---------------------------------------------------------------------------
say "Commit 3/6: model + baseline trainer (then tag v1.0)"
copy backend/model.py backend/train.py run_train.sh tests/test_model.py
commit "feat: XGBoost trainer (baseline) + model loader + tests"
git -C "$BUILD" tag -a v1.0 -m "v1.0 — baseline model, no hyperparameter tuning"

# ---------------------------------------------------------------------------
# 4. dashboard
# ---------------------------------------------------------------------------
say "Commit 4/6: Streamlit dashboard"
copy frontend/theme.py frontend/app.py run_dashboard.sh
commit "feat: Streamlit dashboard with Plotly charts"

# ---------------------------------------------------------------------------
# 5. Bayesian tuning (main's improvement over v1.0; the long job)
# ---------------------------------------------------------------------------
say "Commit 5/6: Optuna Bayesian hyperparameter tuning"
copy backend/tuning.py
commit "feat: Bayesian (Optuna TPE) hyperparameter search for tuned mode"

# ---------------------------------------------------------------------------
# 6. notebooks
# ---------------------------------------------------------------------------
say "Commit 6/6: notebooks"
copy notebooks/01_eda.ipynb notebooks/02_model_experiments.ipynb
commit "docs: EDA + model-experiment notebooks"

# ---------------------------------------------------------------------------
# colleague's unmerged branch: feature/whatif-predictor
# ---------------------------------------------------------------------------
say "Branch: feature/whatif-predictor (colleague's what-if panel)"
git -C "$BUILD" switch -q -c feature/whatif-predictor
copy frontend/whatif.py
commit "feat: interactive what-if price predictor panel"
git -C "$BUILD" switch -q main

# ---------------------------------------------------------------------------
# pack the bundle
# ---------------------------------------------------------------------------
say "Writing bundle: $BUNDLE"
rm -f "$BUNDLE"
git -C "$BUILD" bundle create "$BUNDLE" --all >/dev/null

echo
say "Done. History:"
git -C "$BUILD" log --oneline --graph --all --decorate | sed 's/^/    /'
echo
echo "    bundle: $BUNDLE"
echo "    next:   bash unpack-demo.sh"
