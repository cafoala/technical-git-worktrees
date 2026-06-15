# Git Worktrees — Demo Runsheet

A driver's-seat companion to the slides. Everything here is copy-paste ready. Swap
in your own repo path once at the top and the rest follows.

> **Set this first** (in the terminal you'll present from):
> ```bash
> export REPO=~/projects/myrepo     # <-- your real repo
> cd "$REPO"
> ```
> Use a repo that **builds or runs something** (has a venv, compiles, or has tests) —
> the "switching is expensive" point lands much harder when there's a real build/env behind it.

---

## 20-minute pacing

| Time | Slide(s) | What you're doing |
|------|----------|-------------------|
| 0:00–2:00 | 1–2 | Hook: the mid-refactor-prod-breaks pain |
| 2:00–4:00 | 3 | Why RSEs feel it more (long jobs, builds, envs) |
| 4:00–7:00 | 4–6 | Mental model + the four commands |
| 7:00–16:00 | 7–10 | **Live demo** (the three scenarios below) |
| 16:00–18:30 | 11–13 | Gotchas, tips, when-to-use |
| 18:30–20:00 | 14–15 | Cheat sheet + Q&A |

The demo is the centre of gravity — ~9 minutes. If you're running long, cut scenario 3
(benchmark) and just mention it.

---

## One-time prep (do before you present)

```bash
cd "$REPO"

# make sure you're clean to start, on your main branch
git switch main 2>/dev/null || git switch master
git pull --ff-only

# create some fake "work in progress" so the tree looks dirty during the demo
echo "# half-finished refactor" >> NOTES_demo.md
# don't commit it — that's the point

# confirm starting state
git status
git worktree list      # should show just the main worktree
```

Have **two terminal windows/tabs** open and visible — the whole pitch is "two places at once",
so the audience should literally see two prompts.

---

## Scenario 1 — Hotfix without disturbing your WIP  *(slide 8)*

**Say:** "I'm three files into a refactor, tree is dirty. Pager goes off. Watch — no stash."

```bash
# Terminal A (your repo, mid-work)
git status                              # show the dirty NOTES_demo.md

# spin up a clean checkout of main, on a brand-new branch, in a sibling dir
git worktree add ../myrepo-hotfix -b hotfix main

git worktree list                       # now there are two

cd ../myrepo-hotfix
git status                              # CLEAN — your WIP isn't here
echo "fix" >> README.md
git add -A && git commit -m "hotfix: the urgent thing"
# (push / open PR here in real life)

cd "$REPO"
git status                              # your refactor is exactly as you left it
```

**Point at:** the second `git worktree list` entry, and the *clean* status in the hotfix dir
vs the still-dirty status back home. **"No stash. No WIP commit. No re-clone."**

---

## Scenario 2 — Review a colleague's branch side-by-side  *(slide 9)*

**Say:** "Reviewing a PR usually means stomping on my own checkout. Instead:"

```bash
# Terminal A
git fetch origin

# check out their branch in its own directory
git worktree add ../myrepo-review origin/their-feature
#   (for the demo, swap in any real branch, e.g. origin/main or a tag)

cd ../myrepo-review
# open this folder in a second editor window — run it, test it, read it
```

**Point at:** two editor windows open at once — yours and theirs. Real diffs, real builds,
no context loss. When done:

```bash
cd "$REPO"
git worktree remove ../myrepo-review
```

> If git complains the branch is already checked out elsewhere, that's the
> "one branch, one worktree" rule (slide 11). Use a different branch or add `--detach`.

---

## Scenario 3 — Benchmark / run two versions at once  *(slide 10)*

**Say:** "The RSE killer feature — compare old vs new without flip-flopping branches and
rebuilding between every run."

```bash
# Terminal A: pin a baseline checkout (use a real tag/commit you have)
git worktree add ../myrepo-baseline v1.0     # or an older commit SHA

# Terminal A — run the baseline
cd ../myrepo-baseline
# ./run_bench.sh        (or: pytest, make, your sim — whatever you've got)

# Terminal B — run the current version at the SAME TIME
cd "$REPO"
# ./run_bench.sh
```

**Point at:** both running concurrently, each with its **own** build artifacts / venv —
no shared state, no recompile churn between measurements.

---

## Cleanup / reset (re-run the whole demo from scratch)

```bash
cd "$REPO"

git worktree remove ../myrepo-hotfix    --force 2>/dev/null
git worktree remove ../myrepo-review    --force 2>/dev/null
git worktree remove ../myrepo-baseline  --force 2>/dev/null
git worktree prune                      # clears any stale metadata

git branch -D hotfix 2>/dev/null        # the throwaway branch from scenario 1
rm -f NOTES_demo.md README_changes 2>/dev/null
git checkout -- . 2>/dev/null

git worktree list                       # back to just the main worktree
```

---

## If something goes sideways (live-demo insurance)

- **"fatal: 'hotfix' is already checked out at ..."** — you already have that branch in a
  worktree. `git worktree list` to find it, or pick a new branch name.
- **Removed a worktree folder with `rm -rf` by accident** — `git worktree prune` cleans the
  leftover metadata; the entry disappears from `git worktree list`.
- **`remove` refuses because the worktree is dirty** — add `--force`, or commit/clean first.
- **Lost in the dirs** — `git worktree list` always tells you every checkout and where it is.

---

## The four commands, for reference

```bash
git worktree add <path> [<branch>]      # create (add -b <name> for a new branch)
git worktree list                       # show all worktrees
git worktree remove <path>              # tidy up when done
git worktree prune                      # clean stale metadata
git worktree move <wt> <new-path>       # relocate one
```

**One-liner to remember:** `git worktree add ../proj-fix -b fix origin/main`
— new directory, new branch, correct base, in a single command.
