#!/usr/bin/env bash
#
# unpack-demo.sh — (re)create the demo WORKING repo from the bundle.
#
# Run this once as prep, and again any time you want to RESET between practice
# runs. It clones a fresh working repo next to this talk folder and wires up a
# real bare "origin" remote so the review scenario's origin/feature branch works.
#
#   working repo: ../ml-dashboard-demo
#   bare remote:  ../ml-dashboard-demo-remote.git
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PARENT="$(dirname "$HERE")"
BUNDLE="$HERE/ml-dashboard-demo.bundle"
REPO="$PARENT/ml-dashboard-demo"
REMOTE="$PARENT/ml-dashboard-demo-remote.git"

say() { printf '\033[1;36m==>\033[0m %s\n' "$1"; }

[ -f "$BUNDLE" ] || {
  echo "bundle not found: $BUNDLE  (run: bash build-bundle.sh first)" >&2
  exit 1
}

# demo worktrees created during the talk (cleaned up here on reset)
WORKTREES=(
  "$PARENT/dashboard-colorfix"
  "$PARENT/ml-dashboard-csv"
  "$PARENT/ml-dashboard-tests"
  "$PARENT/ml-dashboard-docs"
  "$PARENT/ml-dashboard-baseline"
  "$PARENT/ml-dashboard-review"
)

# ---------------------------------------------------------------------------
# clean slate
# ---------------------------------------------------------------------------
say "Cleaning previous demo dirs (if any)"
for wt in "$REPO" "${WORKTREES[@]}"; do
  [ -e "$wt/.git" ] && git -C "$wt" worktree prune 2>/dev/null || true
done
rm -rf "$REPO" "$REMOTE" "${WORKTREES[@]}"

# ---------------------------------------------------------------------------
# clone the working repo from the bundle
# ---------------------------------------------------------------------------
say "Cloning working repo -> $REPO"
git clone -q "$BUNDLE" "$REPO"
cd "$REPO"
git config user.name  "Demo Presenter"
git config user.email "you@example.com"
git config commit.gpgsign false 2>/dev/null || true

# keep a local handle on the colleague's branch before we drop the bundle origin
git branch -q feature/whatif-predictor origin/feature/whatif-predictor

# ---------------------------------------------------------------------------
# replace the bundle 'origin' with a real bare remote
# ---------------------------------------------------------------------------
say "Creating bare remote -> $REMOTE"
git remote remove origin
git init -q --bare "$REMOTE"
git remote add origin "$REMOTE"

git push -q -u origin main
git push -q origin v1.0
git push -q origin feature/whatif-predictor

# the review scenario uses origin/feature/whatif-predictor, so drop the local copy
git branch -q -D feature/whatif-predictor
git fetch -q origin

# ---------------------------------------------------------------------------
# done
# ---------------------------------------------------------------------------
say "Done."
echo
git log --oneline --graph --all --decorate | sed 's/^/    /'
echo
echo "    working repo: $REPO"
echo "    bare remote:  $REMOTE"
echo "    branches:"; git branch -a | sed 's/^/      /'
echo
echo "    next:  cd \"$REPO\" && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt"
