# Git Worktrees — Demo Runsheet

A driver's-seat companion to **git-worktrees.pptx** (in this folder). Everything
here is copy-paste ready. The demo runs on **this repo** — a real ML project: an
XGBoost house-price model behind a Streamlit dashboard.

Branches you'll use (both already exist):
- `main` — the working app with a **baseline** model (your initial demo).
- `experiment/bayesian-tuning` — a WIP experiment that adds the Bayesian
  hyperparameter search + a notebook. *Pretend you're creating it live.*

> **Set this first:**
> ```bash
> export REPO=~/Desktop/rse_role/technical-git-worktrees   # this repo, on main
> cd "$REPO"
> ```
> **Running it for another group?** Just clone — every clone is independent, with
> both branches: `git clone <this repo or its URL> ../wt-demo && cd ../wt-demo`.

---

## 20-minute pacing

| Time | Slide(s) | What you're doing |
|------|----------|-------------------|
| 0:00–3:00 | 1–3 | Hook + why RSEs feel branch-switching pain |
| 3:00–5:00 | 4–6 | Mental model + the four commands |
| 5:00–6:30 | 7 | **Demo 1:** here's my working app (baseline) |
| 6:30–9:30 | 8 | **Demo 2a:** experiment + the `git stash` juggling (the pain) |
| 9:30–13:00 | 8 | **Demo 2b:** worktrees — experiment + colour fix at the same time |
| 13:00–15:00 | 9 | **Demo 3:** compare baseline vs tuned side-by-side |
| 15:00–16:30 | 11–13 | Gotchas, tips, when-to-use |
| 16:30–18:30 | 14 | **Demo 4:** parallel AI agents, one worktree each |
| 18:30–20:00 | 15–16 | Cheat sheet + tl;dr + Q&A |

Tight on time? Demo 2 is the centrepiece — keep it. Demo 3 and Demo 4 each stand
alone and can be trimmed to "here's the idea."

---

## One-time prep (do before you present)

```bash
cd "$REPO"                       # on main
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt     # includes jupyterlab

# warm the dataset cache so there's NO live download on stage
.venv/bin/python -c "from sklearn.datasets import fetch_california_housing as f; f()"

# train the baseline so the dashboard shows something
.venv/bin/python -m backend.train
```

**Calibrate the experiment length** so the tuning notebook runs ~5–8 min on *your*
laptop:

```bash
time .venv/bin/python -c "import sys; sys.path.insert(0,'.'); \
from backend.data import load_dataset; from backend.tuning import bayesian_search; \
X,_,y,_ = load_dataset(); bayesian_search(X,y,n_trials=10)" 2>/dev/null
#   ~3s/trial -> set N_TRIALS = 120 in the notebook on experiment/bayesian-tuning
```

Have visible: **two terminals**, the **dashboard** at http://localhost:8501
(`.venv/bin/streamlit run frontend/app.py`), and an editor.

> **Why a worktree beats stashing** (say this): a branch is just a pointer;
> *processes run in a working directory*, and a directory holds one branch at a
> time. While an experiment runs in this directory you can't `git switch` away
> without disturbing it, and `git stash` only shelves edits — it can't free the
> directory for a second task. A worktree gives the other branch its own
> directory, so both run side by side.

---

## DEMO 1 — here's my app  *(slide 7)*

**Say:** "A house-price model behind a dashboard. Here's the model's accuracy,
the feature importances, the predictions." Show http://localhost:8501.

*(Leave it running — it's the baseline you'll compare against later.)*

---

## DEMO 2 — the experiment, the pain, then the relief  *(slide 8)*

### 2a. The OLD way — one directory, `git stash` juggling

**Say:** "I think Bayesian hyperparameter tuning could beat this. I've got a
branch for the experiment — let me jump on it and run it."

```bash
git switch experiment/bayesian-tuning
.venv/bin/jupyter lab notebooks/02_model_experiments.ipynb   # Run-All; "this'll take ages"
```

**Say:** "…and someone messages: the dashboard's red/green chart is unusable if
you're colourblind. I need to fix that. The old way — one directory:"

```bash
git switch main          # try to go fix it...
#   git refuses if the notebook has unsaved changes: "I can't even leave"
git stash                # forced to shelve the experiment
git switch main
#   ...fix the colours the old way...
git switch experiment/bayesian-tuning
git stash pop            # come back to check the experiment
```

**Say:** "I've been flip-flopping, and I could never see the experiment **and**
the fix at the same time. Pain in the arse — and ten times worse if I'd kicked
off three agents." End back on main: `git switch main`.

*(Lower-risk option: narrate 2a and just show `git stash` / `git stash list`
rather than the full dance.)*

### 2b. The RELIEF — worktrees: both at once

**Say:** "Worktrees fix this. The experiment gets its own directory; so does the
fix. My main checkout stays free."

```bash
# experiment in its own directory — start the long job here, leave it running
git worktree add ../tuning-experiment experiment/bayesian-tuning
( cd ../tuning-experiment && WT=$REPO/.venv/bin; "$WT/jupyter" lab notebooks/02_model_experiments.ipynb )
```

```bash
# colour fix in ITS own directory, off main — main checkout never moved
cd "$REPO"
git worktree add ../dashboard-colorfix -b colorblind-fix main
cd ../dashboard-colorfix
```

Edit **frontend/theme.py** — swap red/green for the Okabe–Ito colourblind-safe set:

```python
PALETTE = [
    "#E69F00", "#56B4E9", "#009E73", "#F0E442",
    "#0072B2", "#D55E00", "#CC79A7", "#000000",
]
OVER_PRED = "#D55E00"   # vermillion
UNDER_PRED = "#0072B2"  # blue
PRIMARY = "#0072B2"
```

…and `primaryColor = "#0072B2"` in **.streamlit/config.toml**. Then ship it:

```bash
git add -A && git commit -m "fix: Okabe-Ito colourblind-safe palette"
cd "$REPO"
git merge colorblind-fix          # main was never moved -> clean fast-forward
```

**Point at:** the experiment in `../tuning-experiment` — **still running**. The
fix is merged. You never stashed, never flip-flopped. `git worktree list` shows
it all.

---

## DEMO 3 — compare two versions side-by-side  *(slide 9)*

**Say:** "Now I want to compare my baseline against the tuned experiment —
without flip-flopping branches. Worktrees let me have both checked out at once."

```bash
cd "$REPO"                                   # main: baseline model on :8501
git worktree add ../dashboard-tuned experiment/bayesian-tuning
cd ../dashboard-tuned
"$REPO/.venv/bin/python" -m backend.train --mode tuned --trials 40   # tuned model, its OWN models/
"$REPO/.venv/bin/streamlit" run frontend/app.py --server.port 8502
```

**Point at:** two browser windows — **:8501 baseline vs :8502 tuned** — same app,
two versions, side by side. Compare the RMSE and residuals. Two editor windows
let you diff the code directly too.

**Say:** "Each worktree has its **own** `models/` and environment — so I can even
run both trainings *at the same time* and benchmark them. One directory could
never do that."

---

## DEMO 4 — parallel AI agents, one worktree each  *(slide 14)*

**Say:** "Remember the stash pain got worse with multiple tasks? This is why
agents love worktrees — each gets its own directory and branch, so they never
collide, and none disturbs my running experiment."

```bash
cd "$REPO"
git worktree add ../dashboard-csv   -b agent/csv-export    main
git worktree add ../dashboard-tests -b agent/feature-tests main
git worktree add ../dashboard-docs  -b agent/docstrings    main
git worktree list        # 3 agents, 3 branches, one repo

cd ../dashboard-csv   && claude     # paste prompt A
cd ../dashboard-tests && claude     # paste prompt B
cd ../dashboard-docs  && claude     # paste prompt C
```

| Worktree / branch | Prompt to paste |
|---|---|
| `agent/csv-export` | *In `frontend/app.py`, add a "Download predictions as CSV" button under the predicted-vs-actual chart using `st.download_button` and the predictions DataFrame the app already builds. Reuse `frontend/theme.py`. Don't touch `backend/`.* |
| `agent/feature-tests` | *Write pytest unit tests in `tests/test_data.py` for `add_engineered_features` and `_safe_ratio` in `backend/data.py`, incl. edge cases (zero denominator, missing values). Only modify files under `tests/`. Run `python -m pytest -q`.* |
| `agent/docstrings` | *Add NumPy-style docstrings + PEP 484 type hints to the public functions in `backend/model.py` and `backend/data.py`. Don't change runtime behaviour.* |

**You don't need to wait for them.** The picture is the point: three agents on
three branches at once, no collisions — and the experiment still tuning. Merging
the good ones later is conflict-free (different files).

---

## Cleanup / reset (between practice runs)

```bash
cd "$REPO"
for w in tuning-experiment dashboard-colorfix dashboard-tuned \
         dashboard-csv dashboard-tests dashboard-docs; do
  git worktree remove "../$w" --force 2>/dev/null
done
git worktree prune
git switch main 2>/dev/null
git branch -D colorblind-fix agent/csv-export agent/feature-tests agent/docstrings 2>/dev/null
git stash clear
git checkout -- .              # restore the red/green palette
git worktree list              # back to just the main worktree
```

*Do NOT delete `experiment/bayesian-tuning` — it's part of the demo.* Cleanest of
all: practise on a throwaway clone (`git clone . ../wt-demo`) and `rm -rf` it after.

---

## If something goes sideways (live-demo insurance)

- **"fatal: '<branch>' is already checked out at …"** — it's in a worktree
  already. `git worktree list` to find it, or use a new branch name.
- **`git switch` refuses ("local changes would be overwritten")** — that's the
  stash pain in 2a; `git stash` then switch. (In 2b you avoid it entirely.)
- **Experiment too short/long** — it's `N_TRIALS` in the notebook (or `--trials`).
  Each worktree has its own `models/`, so runs never clash.
- **Removed a worktree folder with `rm -rf`** — `git worktree prune` clears it.
- **`remove` refuses (worktree dirty)** — add `--force`.
- **Dashboard didn't recolour** — hard-refresh the browser.

---

## The four commands, for reference

```bash
git worktree add <path> [<branch>]      # create (add -b <name> for a new branch)
git worktree list                       # show all worktrees
git worktree remove <path>              # tidy up when done
git worktree prune                      # clean stale metadata
```

**One-liner to remember:** `git worktree add ../proj-fix -b fix origin/main`
— new directory, new branch, correct base, in a single command.
