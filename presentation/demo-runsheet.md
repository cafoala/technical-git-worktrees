# Git Worktrees — Demo Runsheet

A driver's-seat companion to **git-worktrees.pptx** (in this folder). Everything
here is copy-paste ready. The demo runs on **this repo** — a small but real ML
project: an XGBoost model with Bayesian hyperparameter tuning behind a Streamlit
dashboard.

The **core narrative** is a before/after: first feel the **`git stash` pain** of
juggling a long-running experiment against an urgent fix in one working
directory, then show how **git worktrees** make the pain vanish — and why that's
exactly what you want when AI agents are each off doing their own task.

> **Set this first** (in the terminal you'll present from):
> ```bash
> export REPO=~/Desktop/rse_role/technical-git-worktrees   # this repo
> cd "$REPO"
> ```
> Practising? Work on a throwaway clone so your demo commits/branches don't pile
> up here: `git clone . ../wt-demo && cd ../wt-demo` (then `export REPO=$PWD`).

---

## 20-minute pacing

| Time | Slide(s) | What you're doing |
|------|----------|-------------------|
| 0:00–2:00 | 1–2 | Hook: mid-task, a long job is running, something urgent lands |
| 2:00–4:00 | 3 | Why RSEs feel it more (a model is training on branch A…) |
| 4:00–6:00 | 4–6 | Mental model + the four commands |
| 6:00–9:00 | 7–8 | **Demo 1a:** run the tuning experiment, then the `git stash` juggling (the pain) |
| 9:00–13:00 | 7–8 | **Demo 1b:** drop the stashes, do it with worktrees while the experiment runs |
| 13:00–16:30 | 11–13 | Gotchas, tips, when-to-use |
| 16:30–18:30 | 14 | **Demo 2:** launch parallel AI agents, one worktree each |
| 18:30–20:00 | 15–16 | Cheat sheet + tl;dr + Q&A |

---

## One-time prep (do before you present)

```bash
cd "$REPO"
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt     # includes jupyterlab

# warm the dataset cache so there's NO live download on stage
.venv/bin/python -c "from sklearn.datasets import fetch_california_housing as f; f()"

# train a model so the dashboard has something to show
.venv/bin/python -m backend.train --mode baseline
```

**Calibrate the experiment length** so the tuning notebook runs ~5–8 minutes on
*your* laptop (long enough to do the colour fix while it churns):

```bash
# time 10 trials, then set N_TRIALS in the notebook so 10*per-trial ≈ 360s
time .venv/bin/python -c "import sys; sys.path.insert(0,'.'); \
from backend.data import load_dataset; from backend.tuning import bayesian_search; \
X,_,y,_ = load_dataset(); bayesian_search(X,y,n_trials=10)"
#   e.g. ~3s/trial  ->  set N_TRIALS = 120 in notebooks/02_model_experiments.ipynb
```

Have visible: **two terminals**, the **dashboard** in a browser tab
(`.venv/bin/streamlit run frontend/app.py` → http://localhost:8501), and the
**experiment notebook** open (Jupyter or VS Code).

> **Why a worktree beats stashing here** (say this — it pre-empts the heckle): a
> branch is just a pointer; *processes run in a working directory*, and a
> directory holds one branch at a time. While the experiment runs in this
> directory, `git switch` would rewrite the files under it, and `git stash` only
> shelves your edits — it can't free the directory for a second task. The
> worktree decouples branch from directory: the experiment keeps running here,
> the fix gets its own directory to edit, run and commit.

---

## DEMO 1 — the pain, then the relief  *(slides 7–8)*

### 1a. Start the long job (the experiment)

**Say:** "I reckon Bayesian tuning will improve my model — let me run this
experiment notebook."

**Do:** open **notebooks/02_model_experiments.ipynb** and Run-All. Section 2 (the
search) starts churning — point at `best` ticking down. Leave it running.

```bash
cd "$REPO"
.venv/bin/jupyter lab notebooks/02_model_experiments.ipynb    # or open in VS Code, Run All
```

### 1b. The interrupt — the OLD way (git stash juggling)

**Say:** "Two minutes in, someone says: the dashboard's red/green chart is
invisible to colourblind users. My tree has uncommitted work and my kernel's
busy. The way I'd usually do this:"

```bash
# in a second terminal, same working dir
cd "$REPO"
git stash                              # shelve my current work
git switch -c fix/colorblind-palette   # new branch, in THIS dir
#   ...edit frontend/theme.py... (it's quick — tell them to pretend it's a 20-min job)
git add -A && git commit -m "fix: colourblind-safe palette"
```

**Say:** "Now — did my tuning finish? I have to come back…"

```bash
git switch -                           # back to where I was
git stash pop                          # restore my WIP
```

**Say:** "And if I'd set **three agents** going on three different tasks, that's
three branches and a stash dance *every single time* I want to peek at one. The
stashes pile up:"

```bash
git stash list                         # the junk drawer fills up — pain in the arse
```

### 1c. The relief — drop the stashes, use worktrees

**Say:** "Let me bin all that and do it properly."

```bash
git stash clear                        # delete every stash
git stash list                         # empty — no more juggling
```

**Say:** "The experiment keeps running in **this** directory — I never touch it.
The fix gets its own directory and branch."

```bash
git worktree add ../dashboard-colorfix -b colorblind-fix main
git worktree list                      # two dirs, two branches, one repo
cd ../dashboard-colorfix
```

Edit **frontend/theme.py** — swap the red/green palette for the Okabe–Ito
colourblind-safe one:

```python
PALETTE = [
    "#E69F00", "#56B4E9", "#009E73", "#F0E442",
    "#0072B2", "#D55E00", "#CC79A7", "#000000",
]
OVER_PRED = "#D55E00"   # vermillion
UNDER_PRED = "#0072B2"  # blue
PRIMARY = "#0072B2"
```

…and `primaryColor = "#0072B2"` in **.streamlit/config.toml**. *(Optional: preview
it in isolation without touching :8501 — from the worktree, `"$REPO/.venv/bin/streamlit"
run frontend/app.py --server.port 8502`.)* Then:

```bash
git add -A && git commit -m "fix: Okabe-Ito colourblind-safe palette"
cd "$REPO"
git merge colorblind-fix               # fast-forward; models/ gitignored, no conflict
```

**Point at:** the notebook — **still running**, never stashed, never switched.
Refresh the dashboard on :8501 → recoloured. *"No stash dance. The experiment
owned its directory the whole time; the fix got its own."* → straight into Demo 2.

---

## DEMO 2 — Parallel AI agents, one worktree each  *(slide 14, the finale)*

**Say:** "Remember the stash pain got *worse* with multiple agents? This is the
fix. I'll point three Claude Code agents at three different jobs — each in its
own worktree on its own branch. They can't collide, because no two touch the same
files, and none of them disturbs my still-running experiment."

```bash
cd "$REPO"
git worktree add ../dashboard-csv   -b agent/csv-export    main
git worktree add ../dashboard-tests -b agent/feature-tests main
git worktree add ../dashboard-docs  -b agent/docstrings    main
git worktree list        # 3 agents, 3 branches, one repo — and the experiment still going
```

Launch an agent in each (separate terminals/tabs) and paste the matching prompt:

```bash
cd ../dashboard-csv   && claude     # then paste prompt A
cd ../dashboard-tests && claude     # then paste prompt B
cd ../dashboard-docs  && claude     # then paste prompt C
```

| Worktree / branch | Prompt to paste |
|---|---|
| `agent/csv-export` | *In `frontend/app.py`, add a "Download predictions as CSV" button under the predicted-vs-actual chart using `st.download_button` and the predictions DataFrame the app already builds. Reuse the colours from `frontend/theme.py`. Don't touch `backend/`.* |
| `agent/feature-tests` | *Write pytest unit tests in `tests/test_data.py` for the feature-engineering functions in `backend/data.py` (`add_engineered_features`, `_safe_ratio`), including edge cases (zero denominator, missing values). Only modify files under `tests/`. Run `python -m pytest -q`.* |
| `agent/docstrings` | *Add NumPy-style docstrings and PEP 484 type hints to the public functions in `backend/model.py` and `backend/data.py`, and a short "## Architecture" note to `README.md`. Don't change runtime behaviour.* |

**You don't need to wait for them.** The picture is the point: three agents on
three branches at once, no collisions, no stashing — while the experiment is
*still* tuning. Show `git worktree list`, let them churn, move to your closing
slides. (Merging the good ones later is conflict-free — different files.)

---

## Cleanup / reset (between practice runs)

```bash
cd "$REPO"
for w in dashboard-colorfix dashboard-csv dashboard-tests dashboard-docs; do
  git worktree remove "../$w" --force 2>/dev/null
done
git worktree prune
git switch main 2>/dev/null
git branch -D colorblind-fix fix/colorblind-palette \
  agent/csv-export agent/feature-tests agent/docstrings 2>/dev/null
git stash clear
git checkout -- .              # restore the red/green palette etc.
git worktree list              # back to just the main worktree
```

*(Cleanest of all: practise on a throwaway clone — `git clone . ../wt-demo` — and
just `rm -rf ../wt-demo` afterwards.)*

---

## If something goes sideways (live-demo insurance)

- **"fatal: '<branch>' is already checked out at …"** — that branch is already in
  a worktree. `git worktree list` to find it, or pick a new branch name.
- **Experiment feels too short/long** — it's `N_TRIALS` in the notebook; change it.
  Each worktree has its **own** `models/` (gitignored), so runs never clash.
- **`git stash pop` conflicts** — exactly the pain you're selling; `git checkout
  --theirs .` or just re-stash. (This is why the worktree half is the relief.)
- **Removed a worktree folder with `rm -rf`** — `git worktree prune` clears stale
  metadata.
- **`remove` refuses (worktree dirty)** — add `--force`, or commit/clean first.
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
