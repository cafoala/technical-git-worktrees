#!/usr/bin/env python3
"""build-deck-v2.py — produce git-worktrees-v2.pptx from the original deck.

Stdlib only (no python-pptx). The original .pptx is never modified: we read it,
rewrite a handful of slide-text runs, clone an existing 4-box slide into a new
"Worktrees + AI agents" slide, and write everything to a NEW file.

Every text edit asserts it matched exactly once — PowerPoint can split a line
across multiple <a:t> runs, so a silent miss would be a bug. If an anchor
doesn't match, the script fails loudly.

Run:  python3 build-deck-v2.py
"""
from __future__ import annotations

import os
import re
import sys
import zipfile
from xml.dom import minidom

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "git-worktrees.pptx")
OUT = os.path.join(HERE, "git-worktrees-v2.pptx")

# Replace the FULL text of the <a:t> run that contains `anchor` (a unique ASCII
# substring within that slide). Replacement text must be XML-safe (escape &).
EDITS: dict[str, list[tuple[str, str]]] = {
    # slide 1 — title: make the example command the colour-fix one
    "ppt/slides/slide1.xml": [
        ("../hotfix -b hotfix main",
         "$ git worktree add ../dashboard-colorfix -b colorblind-fix main"),
    ],
    # slide 3 — tie the "long job" to model training
    "ppt/slides/slide3.xml": [
        ("A job is running on branch A", "A model is training on branch A"),
    ],
    # slide 7 — live demo overview
    "ppt/slides/slide7.xml": [
        ("Urgent hotfix", "Fix while it trains"),
        ("Fix a bug on main without touching your work-in-progress.",
         "Recolour the dashboard while a long training run keeps going."),
        ("Run both at once — benchmark old vs new in parallel.",
         "Train baseline vs tuned at once — compare RMSE."),
    ],
    # slide 8 — scenario 1, rewritten as colour-fix-during-training
    "ppt/slides/slide8.xml": [
        ("Hotfix without disturbing WIP", "Fix the dashboard while it trains"),
        ("mid-feature, tree is dirty", "# a long tuning run is training on main"),
        ("$ git status", "$ python -m backend.train --mode tuned"),
        ("spin up a clean tree on main", "# new branch + dir for the colour fix"),
        ("myrepo-hotfix -b hotfix main",
         "    ../dashboard-colorfix -b colorblind-fix main"),
        ("cd ../myrepo-hotfix", "$ cd ../dashboard-colorfix"),
        ("...fix, commit, push, open PR...",
         "# edit palette, preview on :8502, commit"),
        ("WIP untouched", "$ cd ../ml-dashboard &amp;&amp; git merge colorblind-fix"),
        ("No stash", "Training untouched"),
        ("Your half-done refactor stays exactly as you left it.",
         "The tuning run keeps going in the other terminal."),
        ("Clean build", "Branch + preview"),
        ("The hotfix dir builds on its own; your feature build is untouched.",
         "Fix on its own branch; preview on a second port before merging."),
        ("One step back", "Merge &amp; recolour"),
        ("cd home and carry on — nothing to unstash or un-break.",
         "Merge to main and the dashboard repaints — no stash, no waiting."),
    ],
    # slide 9 — scenario 2, point at the real colleague branch
    "ppt/slides/slide9.xml": [
        ("../review origin/their-feature",
         "    ../review origin/feature/whatif-predictor"),
    ],
    # slide 10 — scenario 3, baseline vs tuned model
    "ppt/slides/slide10.xml": [
        ("Benchmark two versions at once", "Compare two model versions"),
        ("cd ../baseline",
         "$ (cd ../baseline &amp;&amp; ./run_train.sh)"),
        ("the new version", "$ ./run_train.sh   # tuned (main)"),
        ("Old and new execute simultaneously, each with its own env and build.",
         "v1.0 (baseline) and main (tuned) train at once, each its own env."),
    ],
}

# The new slide is a clone of slide 12 with its four boxes re-texted.
CLONE_FROM = "ppt/slides/slide12.xml"
CLONE_FROM_RELS = "ppt/slides/_rels/slide12.xml.rels"
NEW_SLIDE = "ppt/slides/slide16.xml"
NEW_SLIDE_RELS = "ppt/slides/_rels/slide16.xml.rels"
NEW_SLIDE_EDITS: list[tuple[str, str]] = [
    ("MAKE IT PLEASANT", "WHERE THIS IS GOING"),
    ("Habits worth picking up", "Worktrees + AI agents"),
    ("Keep them as siblings", "One repo, many agents"),
    ("repo-hotfix",
     "Each agent gets its own worktree and branch — they never touch the same files."),
    ("Branch off the right base in one go", "No collisions"),
    ("creates the dir and the branch",
     "Agents edit, run and commit independently, in parallel."),
    ("Remove, don", "Long tasks in parallel"),
    ("tidies the metadata",
     "Several agents work one repo at once while a long job keeps running."),
    ("Editors treat each as its own project", "Gaining traction"),
    ("Language servers",
     "Tools like Claude Code use worktrees to run many agent sessions on one repo."),
]


def replace_run(xml: str, anchor: str, new_text: str, where: str) -> str:
    """Replace the whole <a:t> run containing `anchor`; assert exactly one hit."""
    pattern = re.compile(r"<a:t>[^<]*" + re.escape(anchor) + r"[^<]*</a:t>")
    matches = pattern.findall(xml)
    if len(matches) != 1:
        raise SystemExit(
            f"[deck] FAILED in {where}: anchor {anchor!r} matched "
            f"{len(matches)} runs (expected 1). Edit aborted."
        )
    return pattern.sub(lambda _m: f"<a:t>{new_text}</a:t>", xml, count=1)


def main() -> int:
    if not os.path.exists(SRC):
        raise SystemExit(f"[deck] source deck not found: {SRC}")

    with zipfile.ZipFile(SRC) as zin:
        names = zin.namelist()
        data = {n: zin.read(n) for n in names}

    changes = 0

    # 1) in-place text edits on existing slides
    for part, edits in EDITS.items():
        xml = data[part].decode("utf-8")
        for anchor, new_text in edits:
            xml = replace_run(xml, anchor, new_text, part)
            changes += 1
        data[part] = xml.encode("utf-8")

    # 2) build the new agentic slide from a clone of slide 12
    new_xml = data[CLONE_FROM].decode("utf-8")
    for anchor, new_text in NEW_SLIDE_EDITS:
        new_xml = replace_run(new_xml, anchor, new_text, NEW_SLIDE)
        changes += 1
    data[NEW_SLIDE] = new_xml.encode("utf-8")

    # its rels: copy slide12's, minus the notesSlide relationship
    rels = data[CLONE_FROM_RELS].decode("utf-8")
    rels = re.sub(r'<Relationship[^>]*notesSlide[^>]*/>', "", rels)
    data[NEW_SLIDE_RELS] = rels.encode("utf-8")

    # 3) register the new slide in the three manifests
    pres = data["ppt/presentation.xml"].decode("utf-8")
    if '<p:sldId id="268" r:id="rId14"/>' not in pres:
        raise SystemExit("[deck] could not find slide13's sldId to insert after")
    pres = pres.replace(
        '<p:sldId id="268" r:id="rId14"/>',
        '<p:sldId id="268" r:id="rId14"/><p:sldId id="271" r:id="rId22"/>',
    )
    data["ppt/presentation.xml"] = pres.encode("utf-8")

    presrels = data["ppt/_rels/presentation.xml.rels"].decode("utf-8")
    new_rel = (
        '<Relationship Id="rId22" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/'
        'relationships/slide" Target="slides/slide16.xml"/>'
    )
    presrels = presrels.replace("</Relationships>", new_rel + "</Relationships>")
    data["ppt/_rels/presentation.xml.rels"] = presrels.encode("utf-8")

    ct = data["[Content_Types].xml"].decode("utf-8")
    new_override = (
        '<Override PartName="/ppt/slides/slide16.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.'
        'presentationml.slide+xml"/>'
    )
    ct = ct.replace("</Types>", new_override + "</Types>")
    data["[Content_Types].xml"] = ct.encode("utf-8")

    # 4) write the new package
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as zout:
        for n in names:
            zout.writestr(n, data[n])
        zout.writestr(NEW_SLIDE, data[NEW_SLIDE])
        zout.writestr(NEW_SLIDE_RELS, data[NEW_SLIDE_RELS])

    print(f"[deck] wrote {OUT}  ({changes} text edits + 1 new slide)")
    return validate()


def validate() -> int:
    """Re-open the new deck: every XML part parses, and there are 16 slides."""
    with zipfile.ZipFile(OUT) as z:
        slide_parts = [n for n in z.namelist()
                       if re.fullmatch(r"ppt/slides/slide\d+\.xml", n)]
        for n in z.namelist():
            if n.endswith(".xml") or n.endswith(".rels"):
                try:
                    minidom.parseString(z.read(n))
                except Exception as exc:  # noqa: BLE001
                    raise SystemExit(f"[deck] MALFORMED XML in {n}: {exc}")
        body = z.read(NEW_SLIDE).decode("utf-8")

    n_slides = len(slide_parts)
    ok = n_slides == 16 and "Worktrees + AI agents" in body
    print(f"[deck] validation: {n_slides} slides, "
          f"agentic slide present={'Worktrees + AI agents' in body}")
    if not ok:
        raise SystemExit("[deck] validation FAILED")
    print("[deck] OK — open git-worktrees-v2.pptx in PowerPoint/Keynote to eyeball it.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
