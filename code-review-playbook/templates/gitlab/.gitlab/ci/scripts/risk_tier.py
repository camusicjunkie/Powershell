#!/usr/bin/env python3
"""Labels a merge request risk::low, risk::medium or risk::high from the files it changes.

The tier comes from the change, not the author. Globs live in .gitlab/risk-tiers.txt:
  [high]  any changed file matching makes the MR high risk
  [low]   the MR is low risk only if every changed file matches
  anything else is medium.

Opt-in (playbook Phase 6): with AUTO_MERGE_LOW_RISK=true, a low-risk MR whose author has
at least Developer access (TRUSTED_ACCESS_LEVEL, default 30) is set to auto-merge. GitLab
still waits for the pipeline, resolved threads and any approvals the project requires.
If a later push raises the tier, the auto-merge this job set is cancelled.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gitlab_api import GitLab, GitLabError  # noqa: E402

LABELS = {"low": "risk::low", "medium": "risk::medium", "high": "risk::high"}


def glob_to_regex(glob):
    """Git-style globs: ** spans folders, * and ? stay inside one folder."""
    out, i = "", 0
    while i < len(glob):
        if glob.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif glob.startswith("**", i):
            out, i = out + ".*", i + 2
        elif glob[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif glob[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(glob[i]), i + 1
    return re.compile(out + r"\Z")


def load_tiers(path):
    tiers, section = {"high": [], "low": []}, None
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            if line.startswith("[") and line.endswith("]"):
                section = line[1:-1].strip().lower()
                if section not in tiers:
                    sys.exit(f"{path}: unknown section [{section}]")
            elif section:
                tiers[section].append(glob_to_regex(line.lstrip("/")))
    return tiers


def classify(files, tiers):
    if any(rx.match(f) for f in files for rx in tiers["high"]):
        return "high"
    if files and all(any(rx.match(f) for rx in tiers["low"]) for f in files):
        return "low"
    return "medium"


def changed_files(gl):
    try:
        diffs = gl.get_all(f"{gl.mr}/diffs")
    except GitLabError as e:
        if e.status != 404:
            raise
        diffs = gl.get(f"{gl.mr}/changes")["changes"]  # GitLab < 15.7
    files = set()
    for d in diffs:
        files.update(p for p in (d.get("old_path"), d.get("new_path")) if p)
    return sorted(files)


def main():
    gl = GitLab()
    tiers = load_tiers(os.environ.get("RISK_TIERS_FILE", ".gitlab/risk-tiers.txt"))
    mr = gl.get(gl.mr)
    files = changed_files(gl)
    tier = classify(files, tiers)
    print(f"{len(files)} changed file(s) -> {LABELS[tier]}")

    others = [label for t, label in LABELS.items() if t != tier]
    gl.put(gl.mr, {"add_labels": LABELS[tier], "remove_labels": ",".join(others)})

    me = gl.get("/user")["id"]
    auto_merge_on = mr.get("merge_when_pipeline_succeeds") or mr.get("auto_merge_enabled")
    set_by_me = (mr.get("merge_user") or {}).get("id") == me

    if tier != "low":
        if auto_merge_on and set_by_me:
            gl.post(f"{gl.mr}/cancel_merge_when_pipeline_succeeds", {})
            print("No longer low risk: cancelled the auto-merge this job had set.")
        return

    if os.environ.get("AUTO_MERGE_LOW_RISK", "").lower() != "true" or auto_merge_on:
        return
    try:
        member = gl.get(f"{gl.project}/members/all/{mr['author']['id']}")
        access = member["access_level"]
    except GitLabError as e:
        if e.status != 404:
            raise
        access = 0
    if access < int(os.environ.get("TRUSTED_ACCESS_LEVEL", "30")):
        print("Author is not on the trusted list: leaving the merge to a person.")
        return
    try:
        # auto_merge is the newer name; older GitLab versions read merge_when_pipeline_succeeds.
        gl.put(f"{gl.mr}/merge", {"merge_when_pipeline_succeeds": True, "auto_merge": True,
                                  "sha": mr["sha"]})
        print("Low risk from a trusted author: auto-merge set.")
    except GitLabError as e:
        print(f"Could not set auto-merge ({e}). Is the token's role allowed to merge?")


if __name__ == "__main__":
    main()
