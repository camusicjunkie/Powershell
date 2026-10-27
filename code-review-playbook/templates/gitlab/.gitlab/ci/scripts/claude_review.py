#!/usr/bin/env python3
"""Reviews a merge request with Claude Code and posts findings as resolvable MR threads.

Usage: claude_review.py [code|security]

- Findings become discussions (inline where GitLab accepts the position), so
  "All threads must be resolved" blocks the merge until each one is fixed or
  resolved with a reason.
- Convergence: never re-reports earlier findings, reviews only commits pushed since
  its last round, and after REVIEW_MAX_ROUNDS (default 3) reports only Important
  findings and asks the author to rethink the approach.
"""
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gitlab_api import GitLab, GitLabError, require_env  # noqa: E402

SEVERITY = {"important": "🔴 Important", "nit": "🟡 Nit", "pre-existing": "🟣 Pre-existing"}
MAX_DIFF_CHARS = 400_000
TOOLS = "Read,Grep,Glob,Bash(git diff:*),Bash(git log:*),Bash(git show:*),Bash(git blame:*)"

FOCUS = {
    "code": """Find real bugs before they ship. Check that the change does what the MR
description says, fits the rest of the system, and doesn't break other code. For a bug fix,
check that it addresses the root cause. Report only correctness, security and broken-contract
issues: no style, naming or cleanup suggestions.""",
    "security": """Do a security review. Look for injection (SQL, command, path, template),
authentication and authorization gaps, secrets in code or logs, unsafe deserialization, SSRF,
insecure crypto or randomness, unsafe file handling, and risky CI/CD or dependency changes.
Report only issues an attacker could realistically exploit, not theoretical hardening.""",
}

INSTRUCTIONS = """You are the {mode} reviewer for merge request !{iid} in this repository: "{title}".

MR description:
{description}

{focus}

Follow REVIEW.md and CLAUDE.md in the repo root if they exist. They override these
instructions where they conflict. The diff to review ({scope}) is on standard input. You may
read any file and run git diff/log/show/blame to understand the surrounding code.

Rules:
- Every finding cites a file path that exists and a line number in the new version of the file.
  Never guess filenames.
- Severity: "important" (would break something for users), "nit" (minor but real),
  "pre-existing" (a serious bug in code this MR didn't change).
- When a finding is one of a class, name the class in bug_class and list every instance in the
  body, so the author can fix them all at once.
- Do NOT report anything already raised in earlier rounds (listed below), resolved or not.
{cap_rule}
Already reported:
{previous}

Reply with ONLY this JSON, no prose before or after it:
{{"summary": "<one or two sentences>", "findings": [{{"severity": "important|nit|pre-existing",
"path": "<file>", "line": <int>, "title": "<short>", "body": "<what breaks and how to fix it>",
"bug_class": "<class or empty>"}}]}}"""


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def is_ancestor(old, new):
    return subprocess.run(["git", "merge-base", "--is-ancestor", old, new],
                          capture_output=True).returncode == 0


def run_claude(instructions, diff):
    cmd = ["claude", "-p", instructions, "--output-format", "json",
           "--max-turns", os.environ.get("REVIEW_MAX_TURNS", "40"), "--allowedTools", TOOLS]
    if os.environ.get("CLAUDE_MODEL"):
        cmd += ["--model", os.environ["CLAUDE_MODEL"]]
    proc = subprocess.run(cmd, input=diff, capture_output=True, text=True, timeout=1800)
    if proc.returncode != 0:
        sys.exit(f"claude exited with {proc.returncode}:\n{proc.stderr[-2000:]}")
    envelope = json.loads(proc.stdout)
    if envelope.get("is_error"):
        sys.exit(f"claude reported an error: {envelope.get('result')}")
    return parse_result(envelope.get("result", ""))


def parse_result(text):
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end < start:
        sys.exit(f"No JSON in Claude's reply:\n{text[:2000]}")
    data = json.loads(text[start:end + 1])
    findings = []
    for f in data.get("findings") or []:
        path, line = str(f.get("path", "")).removeprefix("./"), f.get("line")
        if not os.path.isfile(path) or not isinstance(line, int) or line < 1:
            print(f"Dropping finding without a valid location: {path}:{line} {f.get('title')}")
            continue
        sev = str(f.get("severity", "")).lower()
        findings.append({**f, "path": path, "severity": sev if sev in SEVERITY else "important"})
    order = list(SEVERITY)
    findings.sort(key=lambda f: order.index(f["severity"]))
    return data.get("summary", ""), findings


def finding_body(marker, mode, f, positioned):
    label = SEVERITY[f["severity"]] + (" · Security" if mode == "security" else "")
    lines = [marker, f"**{label}**: {f.get('title', '').strip()}"]
    if not positioned:
        lines.append(f"`{f['path']}:{f['line']}`")
    lines += ["", str(f.get("body", "")).strip()]
    if f.get("bug_class"):
        lines += ["", f"_Bug class: {f['bug_class']}. Fix every instance, not just this line._"]
    lines += ["", "_Fix it, or resolve this thread with a one-line reason._"]
    return "\n".join(lines)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "code"
    if mode not in FOCUS:
        sys.exit("usage: claude_review.py [code|security]")
    require_env("ANTHROPIC_API_KEY")
    gl = GitLab()
    max_rounds = int(os.environ.get("REVIEW_MAX_ROUNDS", "3"))
    summary_tag, finding_tag = f"<!-- claude-review:{mode} ", f"<!-- claude-finding:{mode} -->"

    mr = gl.get(gl.mr)
    refs = mr["diff_refs"]
    head = refs["head_sha"]
    notes = gl.get_all(f"{gl.mr}/notes", sort="asc", order_by="created_at")
    rounds = [n for n in notes if n["body"].startswith(summary_tag)]
    previous = [n["body"].replace(finding_tag, "").strip()[:300] for n in notes
                if n["body"].startswith(finding_tag)]

    last_sha = None
    if rounds:
        m = re.search(r"sha=([0-9a-f]{7,40})", rounds[-1]["body"])
        last_sha = m.group(1) if m else None
    if last_sha and head.startswith(last_sha):
        print(f"Already reviewed {head[:8]}; nothing new.")
        return

    round_no = len(rounds) + 1
    if last_sha and is_ancestor(last_sha, head):
        diff, scope = git("diff", last_sha, head), f"commits since the last review, {last_sha[:8]}..{head[:8]}"
    else:
        diff, scope = git("diff", refs["base_sha"], head), "the whole merge request"
    if not diff.strip():
        print("Empty diff; nothing to review.")
        return
    if len(diff) > MAX_DIFF_CHARS:
        diff = diff[:MAX_DIFF_CHARS] + "\n[diff truncated: run git diff to see the rest]\n"

    capped = round_no > max_rounds
    cap_rule = ("- This MR has already had several review rounds. Report ONLY important findings.\n"
                if capped else "")
    instructions = INSTRUCTIONS.format(
        mode=mode, iid=mr["iid"], title=mr["title"], description=(mr.get("description") or "")[:4000],
        focus=FOCUS[mode], scope=scope, cap_rule=cap_rule,
        previous="\n".join(f"- {p}" for p in previous[-60:]) or "(none)")

    summary, findings = run_claude(instructions, diff)
    if capped:
        findings = [f for f in findings if f["severity"] == "important"]

    for f in findings:
        position = {"position_type": "text", "base_sha": refs["base_sha"], "start_sha": refs["start_sha"],
                    "head_sha": head, "old_path": f["path"], "new_path": f["path"], "new_line": f["line"]}
        try:
            gl.post(f"{gl.mr}/discussions",
                    {"body": finding_body(finding_tag, mode, f, True), "position": position})
        except GitLabError:
            # Line is outside the diff: post an unpositioned thread that still blocks the merge.
            gl.post(f"{gl.mr}/discussions", {"body": finding_body(finding_tag, mode, f, False)})

    counts = {s: sum(f["severity"] == s for f in findings) for s in SEVERITY}
    tally = ", ".join(f"{n} {SEVERITY[s]}" for s, n in counts.items() if n)
    lines = [f"{summary_tag}round={round_no} sha={head} -->",
             f"**Claude {mode} review**, round {round_no} ({scope})", "",
             f"Found {len(findings)} issue(s): {tally}." if findings else "**No issues found.**"]
    if summary:
        lines += ["", summary]
    if capped and counts["important"]:
        lines += ["", f"⚠️ This MR has been through {round_no} review rounds and important issues keep "
                      "coming back. Consider stepping back and rethinking the approach instead of "
                      "patching line by line."]
    gl.post(f"{gl.mr}/notes", {"body": "\n".join(lines)})
    print("\n".join(lines[1:]))


if __name__ == "__main__":
    main()
