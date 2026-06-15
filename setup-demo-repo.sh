#!/usr/bin/env bash
#
# setup-demo-repo.sh — build the git-worktrees demo project from scratch.
#
# Creates two sibling directories next to this talk folder:
#   ../worktree-demo            the working repo (a small Python package, "wordstats")
#   ../worktree-demo-remote.git a bare repo used as `origin`
#
# The history is shaped for the three demo scenarios in demo-runsheet.md:
#   * tag v1.0  ........ the SLOW analyzer (naive counting)        -> benchmark baseline
#   * main      ........ the FAST analyzer (collections.Counter)   -> benchmark "new"
#   * origin/their-feature  an unmerged CSV-export branch          -> review side-by-side
#
# Idempotent: re-run it any time to reset for another practice run.
# (Remove any demo worktrees first — see the cleanup block in demo-runsheet.md.)

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PARENT="$(dirname "$HERE")"
REPO="$PARENT/worktree-demo"
REMOTE="$PARENT/worktree-demo-remote.git"
GITIGNORE_SRC="$HERE/.gitignore"

say() { printf '\033[1;36m==>\033[0m %s\n' "$1"; }

# ---------------------------------------------------------------------------
# 0. Clean slate
# ---------------------------------------------------------------------------
say "Cleaning previous demo dirs (if any)"
for wt in "$REPO" "$PARENT/worktree-demo-hotfix" "$PARENT/worktree-demo-review" \
          "$PARENT/worktree-demo-baseline"; do
  if [ -d "$wt/.git" ] || [ -f "$wt/.git" ]; then
    git -C "$wt" worktree prune 2>/dev/null || true
  fi
done
rm -rf "$REPO" "$REMOTE" \
       "$PARENT/worktree-demo-hotfix" \
       "$PARENT/worktree-demo-review" \
       "$PARENT/worktree-demo-baseline"

# ---------------------------------------------------------------------------
# 1. Bare "remote"
# ---------------------------------------------------------------------------
say "Creating bare remote at $REMOTE"
git init -q --bare "$REMOTE"
git --git-dir="$REMOTE" symbolic-ref HEAD refs/heads/main

# ---------------------------------------------------------------------------
# 2. Working repo
# ---------------------------------------------------------------------------
say "Initialising working repo at $REPO"
mkdir -p "$REPO"
cd "$REPO"
git init -q
git symbolic-ref HEAD refs/heads/main
git config user.name  "Demo Author"
git config user.email "demo-author@example.com"
git config commit.gpgsign false 2>/dev/null || true

# helper: write a file (creating parent dirs), content comes from stdin
w() { mkdir -p "$(dirname "$1")"; cat > "$1"; }
commit() { git add -A && git commit -q -m "$1"; }

# ===========================================================================
# COMMIT 1 — project scaffold
# ===========================================================================
say "Commit 1/7: scaffold"

cp "$GITIGNORE_SRC" "$REPO/.gitignore"
# make sure the demo artifacts are ignored regardless of the base .gitignore
cat >> "$REPO/.gitignore" <<'IGN'

# --- wordstats demo artifacts ---
.venv/
data/corpus.txt
IGN

w pyproject.toml <<'TOML'
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "wordstats"
version = "1.0.0"
description = "A tiny word-frequency analyzer (git-worktree demo project)."
readme = "README.md"
requires-python = ">=3.8"
dependencies = []

[project.optional-dependencies]
dev = ["pytest"]

[project.scripts]
wordstats = "wordstats.cli:main"

[tool.setuptools.packages.find]
where = ["src"]
TOML

w README.md <<'MD'
# wordstats

A tiny word-frequency analyzer used to demo `git worktree`.

```bash
python -m wordstats top data/corpus.txt --n 10
```
MD

w src/wordstats/__init__.py <<'PY'
"""wordstats — a tiny word-frequency analyzer (git-worktree demo)."""

__version__ = "1.0.0"
PY

w src/wordstats/__main__.py <<'PY'
import sys

from .cli import main

if __name__ == "__main__":
    sys.exit(main())
PY

commit "chore: project scaffold (pyproject, package layout, .gitignore)"

# ===========================================================================
# COMMIT 2 — tokenizer + stopwords + its test
# ===========================================================================
say "Commit 2/7: tokenizer"

w src/wordstats/stopwords.py <<'PY'
"""A small built-in stop-word list (kept tiny on purpose)."""

STOPWORDS = frozenset(
    {
        "the", "a", "an", "and", "or", "but", "if", "of", "to", "in", "on",
        "for", "with", "as", "at", "by", "from", "is", "are", "was", "were",
        "be", "been", "being", "it", "its", "this", "that", "these", "those",
        "we", "you", "they", "he", "she", "i", "me", "my", "our", "us",
        "had", "has", "have", "do", "did", "does", "not", "no", "so", "all",
        "before", "after", "other", "way", "us",
    }
)
PY

w src/wordstats/tokenizer.py <<'PY'
"""Turn raw text into a list of lowercase word tokens."""

import re

from .stopwords import STOPWORDS

_WORD_RE = re.compile(r"[a-z']+")


def tokenize(text, *, remove_stopwords=True):
    """Lowercase, split on non-letters, optionally drop stop-words."""
    tokens = (t.strip("'") for t in _WORD_RE.findall(text.lower()))
    tokens = [t for t in tokens if t]
    if remove_stopwords:
        tokens = [t for t in tokens if t not in STOPWORDS]
    return tokens
PY

w tests/test_tokenizer.py <<'PY'
from wordstats.tokenizer import tokenize


def test_lowercases_and_splits():
    assert tokenize("Hello, HELLO world!", remove_stopwords=False) == [
        "hello",
        "hello",
        "world",
    ]


def test_removes_stopwords():
    toks = tokenize("the cat and the hat", remove_stopwords=True)
    assert "the" not in toks
    assert "and" not in toks
    assert toks == ["cat", "hat"]
PY

commit "feat: tokenizer + stop-word filtering"

# ===========================================================================
# COMMIT 3 — analyzer (SLOW, naive counting) + its test
# ===========================================================================
say "Commit 3/7: analyzer (naive)"

w src/wordstats/analyzer.py <<'PY'
"""Word-frequency analysis.

NOTE: this is the naive baseline. For every *unique* token we rescan the whole
token list with ``list.count`` — that is O(unique x total) and gets slow fast.
A later commit replaces it with collections.Counter.
"""

from .tokenizer import tokenize


def word_frequencies(text, *, remove_stopwords=True):
    tokens = tokenize(text, remove_stopwords=remove_stopwords)
    freqs = {}
    for tok in set(tokens):          # naive: one full scan per unique word
        freqs[tok] = tokens.count(tok)
    return freqs


def top_words(text, n=10, *, remove_stopwords=True):
    freqs = word_frequencies(text, remove_stopwords=remove_stopwords)
    ordered = sorted(freqs.items(), key=lambda kv: (-kv[1], kv[0]))
    return ordered[:n]
PY

w tests/test_analyzer.py <<'PY'
from wordstats.analyzer import top_words, word_frequencies

TEXT = "apple apple apple banana banana cherry"


def test_word_frequencies():
    freqs = word_frequencies(TEXT, remove_stopwords=False)
    assert freqs == {"apple": 3, "banana": 2, "cherry": 1}


def test_top_words_orders_by_count():
    pairs = top_words(TEXT, n=2, remove_stopwords=False)
    assert pairs[0] == ("apple", 3)
    assert pairs[1] == ("banana", 2)
PY

commit "feat: word-frequency analyzer (naive counting)"

# ===========================================================================
# COMMIT 4 — CLI + reporting
# ===========================================================================
say "Commit 4/7: CLI + reporting"

w src/wordstats/report.py <<'PY'
"""Format analysis results for the terminal."""


def format_table(pairs):
    """Render (word, count) pairs as a simple aligned two-column table."""
    if not pairs:
        return "(no words)"
    width = max(len(word) for word, _ in pairs)
    rows = [f"{word:<{width}}  {count}" for word, count in pairs]
    return "\n".join(rows)
PY

w src/wordstats/cli.py <<'PY'
"""Command-line interface for wordstats."""

import argparse
import sys

from . import __version__
from .analyzer import top_words, word_frequencies
from .report import format_table


def _read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def build_parser():
    parser = argparse.ArgumentParser(
        prog="wordstats", description="A tiny word-frequency analyzer."
    )
    parser.add_argument(
        "--version", action="version", version=f"%(prog)s {__version__}"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_top = sub.add_parser("top", help="show the N most frequent words")
    p_top.add_argument("path", help="text file to analyze")
    p_top.add_argument("--n", type=int, default=10, help="how many to show")
    p_top.add_argument(
        "--keep-stopwords", action="store_true", help="do not drop stop-words"
    )

    p_count = sub.add_parser("count", help="count total and unique words")
    p_count.add_argument("path", help="text file to analyze")
    p_count.add_argument("--keep-stopwords", action="store_true")

    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    text = _read(args.path)
    remove_stopwords = not args.keep_stopwords

    if args.command == "top":
        pairs = top_words(text, n=args.n, remove_stopwords=remove_stopwords)
        print(format_table(pairs))
    elif args.command == "count":
        freqs = word_frequencies(text, remove_stopwords=remove_stopwords)
        print(f"total words:  {sum(freqs.values())}")
        print(f"unique words: {len(freqs)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY

commit "feat: CLI (top/count) + table reporting"

# ===========================================================================
# COMMIT 5 — sample corpus + corpus generator + benchmark script
# ===========================================================================
say "Commit 5/7: corpus + bench (then tag v1.0)"

w data/sample.txt <<'TXT'
It was the best of times, it was the worst of times, it was the age of
wisdom, it was the age of foolishness, it was the epoch of belief, it was
the epoch of incredulity, it was the season of Light, it was the season of
Darkness, it was the spring of hope, it was the winter of despair, we had
everything before us, we had nothing before us, we were all going direct to
Heaven, we were all going direct the other way. The town was quiet, the
river ran slow, and the lamps along the harbour glowed against the early
darkness while travellers hurried home with letters, parcels, hopes and small
private worries folded carefully inside their coats.
TXT

w scripts/gen_corpus.py <<'PY'
#!/usr/bin/env python3
"""Build a large, deterministic corpus at data/corpus.txt for benchmarking.

Frequent words are drawn from data/sample.txt (so `wordstats top` shows real
words); a long tail of rare synthetic terms inflates the *unique* count, which
is exactly what makes the v1.0 naive counter slow and the main Counter fast.

Tunables (env vars):
  WORDSTATS_TOKENS  total tokens to emit          (default 150000)
  WORDSTATS_TAIL    size of the rare-word tail    (default 4000)

Defaults make the v1.0 naive counter take ~5s and the main Counter <0.1s on a
typical laptop. Bump both (e.g. WORDSTATS_TOKENS=300000) for a bigger gap.
"""

import os
import random
import string

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SAMPLE = os.path.join(ROOT, "data", "sample.txt")
CORPUS = os.path.join(ROOT, "data", "corpus.txt")

N_TOKENS = int(os.environ.get("WORDSTATS_TOKENS", "150000"))
N_TAIL = int(os.environ.get("WORDSTATS_TAIL", "4000"))


def _tail_word(i):
    """Map an int to a purely-alphabetic token like 'zzab' (tokenizer-safe)."""
    s = ""
    i += 1
    while i:
        i, r = divmod(i - 1, 26)
        s = string.ascii_lowercase[r] + s
    return "zz" + s


def main():
    with open(SAMPLE, encoding="utf-8") as fh:
        common = [w.strip(string.punctuation).lower() for w in fh.read().split()]
    common = [w for w in common if w.isalpha() and len(w) > 3]
    tail = [_tail_word(i) for i in range(N_TAIL)]

    rng = random.Random(20240601)  # fixed seed -> identical corpus every run
    tokens = []
    for _ in range(N_TOKENS):
        if rng.random() < 0.65:
            tokens.append(rng.choice(common))
        else:
            tokens.append(rng.choice(tail))

    with open(CORPUS, "w", encoding="utf-8") as fh:
        for i in range(0, len(tokens), 14):
            fh.write(" ".join(tokens[i : i + 14]) + "\n")

    print(f"wrote {CORPUS}: {len(tokens)} tokens, ~{len(set(tokens))} unique")


if __name__ == "__main__":
    main()
PY
chmod +x scripts/gen_corpus.py

w run_bench.sh <<'SH'
#!/usr/bin/env bash
# Benchmark `wordstats top` on this checkout. Each worktree gets its OWN .venv
# and its OWN generated corpus — nothing is shared. That is the whole point.
set -euo pipefail
cd "$(dirname "$0")"

# 1. per-worktree virtualenv (the "environment doesn't follow the branch" bit)
[ -d .venv ] || python3 -m venv .venv
PY=.venv/bin/python

# 2. make the package importable. Prefer an editable install; if that is not
#    possible offline (e.g. no setuptools in the venv), fall back to PYTHONPATH.
if ! .venv/bin/pip install -e . -q --no-build-isolation >/dev/null 2>&1; then
  export PYTHONPATH="$PWD/src"
fi

# 3. per-worktree corpus
[ -f data/corpus.txt ] || "$PY" scripts/gen_corpus.py

echo "== checkout: $(git describe --tags --always 2>/dev/null || echo '?') =="
time "$PY" -m wordstats top data/corpus.txt --n 10
SH
chmod +x run_bench.sh

w Makefile.tmp <<'MK'
.PHONY: venv install test bench clean
PY := python3
VENV := .venv

venv:
@@$(PY) -m venv $(VENV)

install: venv
@@$(VENV)/bin/pip install -e . --no-build-isolation

test: install
@@$(VENV)/bin/python -m pytest -q

bench:
@@./run_bench.sh

clean:
@@rm -rf $(VENV) data/corpus.txt
MK
# convert the @@ markers to real tabs (Makefiles require tab-indented recipes)
sed 's/^@@/\t/' Makefile.tmp > Makefile
rm -f Makefile.tmp

commit "feat: sample corpus + gen_corpus + run_bench.sh + Makefile"

say "Tagging v1.0 (the slow baseline)"
git tag -a v1.0 -m "wordstats 1.0 — naive counting baseline"

# ===========================================================================
# COMMIT 6 — optimise the analyzer (FAST). This is why v1.0 != main.
# ===========================================================================
say "Commit 6/7: optimise analyzer (Counter)"

w src/wordstats/analyzer.py <<'PY'
"""Word-frequency analysis.

Counting is done in a single pass with collections.Counter — O(total) instead
of the old O(unique x total) rescans. See tag v1.0 for the naive version.
"""

from collections import Counter

from .tokenizer import tokenize


def word_frequencies(text, *, remove_stopwords=True):
    tokens = tokenize(text, remove_stopwords=remove_stopwords)
    return dict(Counter(tokens))


def top_words(text, n=10, *, remove_stopwords=True):
    counts = Counter(tokenize(text, remove_stopwords=remove_stopwords))
    return counts.most_common(n)
PY

commit "perf: count words in one pass with collections.Counter"

# ===========================================================================
# COMMIT 7 — docs (README + presenter notes)
# ===========================================================================
say "Commit 7/7: docs + presenter notes"

w README.md <<'MD'
# wordstats

A tiny, dependency-free word-frequency analyzer. It exists to make a
`git worktree` talk concrete — it has just enough layers (an installable
package, a CLI, tests, a benchmark and a per-checkout environment) that
switching branches in place would actually hurt.

## Install / run

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -e .

wordstats top  data/corpus.txt --n 10     # most frequent words
wordstats count data/corpus.txt           # total / unique counts
```

No network needed: there are no third-party runtime dependencies.

## Layout

```
src/wordstats/
  tokenizer.py   lowercase + split + drop stop-words
  analyzer.py    word_frequencies / top_words   <-- the perf-sensitive bit
  report.py      format results for the terminal
  cli.py         argparse front-end (top / count)
scripts/gen_corpus.py   build a big deterministic data/corpus.txt
run_bench.sh            time `top` on this checkout (own .venv + corpus)
tests/                  pytest suite
```

## Benchmark

```bash
./run_bench.sh
```

`v1.0` counts naively (slow); `main` uses `collections.Counter` (fast) — run
the benchmark in two worktrees to see the gap without rebuilding anything.
MD

w PRESENTER.md <<'MD'
# Presenter notes — wired to THIS repo

Repo:    `../worktree-demo`   (you are here)
Remote:  `../worktree-demo-remote.git`  (added as `origin`)
Baseline tag: `v1.0`   ·   review branch: `origin/their-feature`

Open **two terminals** in this directory. Reset between runs with
`bash ../technical-git-worktrees/setup-demo-repo.sh` (remove demo worktrees first).

---

## Scenario 1 — Hotfix without disturbing WIP

```bash
echo "# half-finished refactor" >> NOTES_demo.md   # dirty the tree
git status

git worktree add ../worktree-demo-hotfix -b hotfix main
git worktree list

cd ../worktree-demo-hotfix
git status                                          # CLEAN — WIP isn't here
echo "" >> README.md && echo "Hotfix: clarify usage." >> README.md
git add -A && git commit -m "hotfix: the urgent thing"

cd ../worktree-demo
git status                                          # your WIP, untouched
```

## Scenario 2 — Review a colleague's branch side-by-side

```bash
git fetch origin
git worktree add ../worktree-demo-review origin/their-feature
cd ../worktree-demo-review

# the branch adds CSV export — run it:
./run_bench.sh >/dev/null 2>&1 || true              # builds its own .venv + corpus
.venv/bin/python -m wordstats top data/corpus.txt --n 5 --csv

cd ../worktree-demo
git worktree remove ../worktree-demo-review
```

## Scenario 3 — Benchmark two versions at once

```bash
git worktree add ../worktree-demo-baseline v1.0

# Terminal A — the slow baseline
(cd ../worktree-demo-baseline && ./run_bench.sh)

# Terminal B — current main (fast)
./run_bench.sh
```

Each worktree builds its **own** `.venv` and `data/corpus.txt` — same input,
no shared state, no rebuild churn between measurements.

## Cleanup

```bash
git worktree remove ../worktree-demo-hotfix   --force 2>/dev/null
git worktree remove ../worktree-demo-review   --force 2>/dev/null
git worktree remove ../worktree-demo-baseline --force 2>/dev/null
git worktree prune
git branch -D hotfix 2>/dev/null
rm -f NOTES_demo.md
git checkout -- . 2>/dev/null
git worktree list
```
MD

commit "docs: expand README + add presenter notes"

# ===========================================================================
# Branch: their-feature (CSV export) — left UNMERGED, pushed to origin only
# ===========================================================================
say "Building their-feature (CSV export) branch"
git switch -q -c their-feature

w src/wordstats/report.py <<'PY'
"""Format analysis results for the terminal (and now CSV)."""

import csv
import io


def format_table(pairs):
    """Render (word, count) pairs as a simple aligned two-column table."""
    if not pairs:
        return "(no words)"
    width = max(len(word) for word, _ in pairs)
    rows = [f"{word:<{width}}  {count}" for word, count in pairs]
    return "\n".join(rows)


def to_csv(pairs):
    """Render (word, count) pairs as CSV text with a header row."""
    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(["word", "count"])
    writer.writerows(pairs)
    return buf.getvalue()
PY

commit "feat: CSV export helper (report.to_csv)"

w src/wordstats/cli.py <<'PY'
"""Command-line interface for wordstats."""

import argparse
import sys

from . import __version__
from .analyzer import top_words, word_frequencies
from .report import format_table, to_csv


def _read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def build_parser():
    parser = argparse.ArgumentParser(
        prog="wordstats", description="A tiny word-frequency analyzer."
    )
    parser.add_argument(
        "--version", action="version", version=f"%(prog)s {__version__}"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_top = sub.add_parser("top", help="show the N most frequent words")
    p_top.add_argument("path", help="text file to analyze")
    p_top.add_argument("--n", type=int, default=10, help="how many to show")
    p_top.add_argument(
        "--keep-stopwords", action="store_true", help="do not drop stop-words"
    )
    p_top.add_argument(
        "--csv", action="store_true", help="emit CSV instead of a table"
    )

    p_count = sub.add_parser("count", help="count total and unique words")
    p_count.add_argument("path", help="text file to analyze")
    p_count.add_argument("--keep-stopwords", action="store_true")

    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    text = _read(args.path)
    remove_stopwords = not args.keep_stopwords

    if args.command == "top":
        pairs = top_words(text, n=args.n, remove_stopwords=remove_stopwords)
        if getattr(args, "csv", False):
            print(to_csv(pairs), end="")
        else:
            print(format_table(pairs))
    elif args.command == "count":
        freqs = word_frequencies(text, remove_stopwords=remove_stopwords)
        print(f"total words:  {sum(freqs.values())}")
        print(f"unique words: {len(freqs)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY

commit "feat: wire --csv flag into the top command"

# ===========================================================================
# Publish to origin, then keep only origin/their-feature locally
# ===========================================================================
say "Pushing to origin"
git switch -q main
git remote add origin "$REMOTE"
git push -q -u origin main
git push -q origin their-feature
git push -q origin v1.0

# Drop the LOCAL their-feature branch so the review demo uses origin/their-feature
git branch -q -D their-feature
git fetch -q origin                       # populate origin/* remote-tracking refs

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
say "Done. Summary:"
echo
git -C "$REPO" log --oneline --graph --all --decorate | sed 's/^/    /'
echo
echo "    repo:   $REPO"
echo "    remote: $REMOTE"
echo "    branches:"; git -C "$REPO" branch -a | sed 's/^/      /'
echo
echo "    Next:  cd $REPO  &&  cat PRESENTER.md"
