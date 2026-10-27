# Code Review Playbook

A reusable implementation plan for AI-assisted code review, adapted from
Addy Osmani's write-up *"How the Claude Code team does code review"*. Drop it
into any repository, current or future, with `Install-ReviewKit.ps1`, then work
through the phases below.

## The idea in one paragraph

You don't stop reviewing code. You move most of the reading to automation and
keep human attention for the risky parts. Review is a stack of layers, and each
layer catches bugs the others miss: pre-PR verification, AI review, security
review, blocking CI, human approval scaled by risk, then merge queue, flags and
rollback. You measure success by **human time spent** (review time *plus* time
spent fixing escaped bugs), and you use **revert and incident rates** as the
guardrail. If reverts go up, you haven't saved time, you've only moved it.

## Targets to track

| Metric | Why |
| --- | --- |
| Median (and p95) human approvals per PR | Goal: most PRs merge with at most one person in the loop, who can be the author. |
| Human comments per PR, time a PR waits on a person | The human-time cost of review. |
| Review rounds until a PR passes | Agent author and agent reviewer must *converge*. |
| Revert rate, incident rate | The guardrail. If either rises, tighten again. |
| AI finding outcomes: fixed / rejected / intentional / didn't matter | Measures reviewer noise. |

---

## Phase 0: Install the kit (5 minutes per repo)

```powershell
# From a clone of this repo; works with Windows PowerShell 5.1 or PowerShell 7+
./code-review-playbook/Install-ReviewKit.ps1 -Path ../my-project -Owner my-github-handle
```

It copies the templates below into the target repo and **never overwrites**
existing files unless you pass `-Force`. Files it skipped are listed so you can
merge them by hand.

| File | Purpose |
| --- | --- |
| `CLAUDE.md` | Short project context and the checks the agent must run before saying "done". |
| `REVIEW.md` | What the reviewer should care about and ignore, and its output format. |
| `.github/pull_request_template.md` | Testing / Risk / How to revert. |
| `.github/CODEOWNERS` | Humans who must approve sensitive paths. |
| `.github/labeler.yml` + `workflows/risk-label.yml` | Labels each PR with a risk tier based on the files it changes; can auto-merge low-risk PRs (off by default). |
| `.github/workflows/claude-code-review.yml` | AI review on every PR, with a cap on review rounds. |
| `.github/workflows/security-review.yml` | Automated security review. |
| `.claude/settings.json` + `.claude/hooks/format-on-edit.sh` | Runs the formatter and linter every time the agent edits a file. |
| `docs/review-evals/incidents.md` | The incident log that becomes your reviewer eval set. |

---

## Phase 1: Before the pull request (the biggest win)

Most of the review happens before a PR exists. Giving the agent a way to
verify its work is the single biggest quality lever, estimated at 2–3× better
output.

1. **Fill in `CLAUDE.md`.** Keep it short: stack, conventions, non-goals, and
   a list of runnable checks (build, test, lint, and for UI work a screenshot
   compared against the design). Link to longer docs rather than inlining them.
2. **Require evidence, not claims.** The agent must *show* the test or command
   output instead of saying "done". This is already written into the
   `CLAUDE.md` template.
3. **Format and lint automatically.** Edit `.claude/hooks/format-on-edit.sh`
   so it calls this project's formatter (PSScriptAnalyzer, Prettier, ruff,
   gofmt, …).
4. **Self-review with fresh context** before opening the PR:
   - `/code-review` (correctness) and `/security-review` in Claude Code, or
   - a subagent prompt: *"Review the diff on this branch with fresh eyes; find
     bugs, not style."*
5. **Fix recurring findings at the source.** When the reviewer keeps flagging
   the same thing, add a lint rule, a line in `CLAUDE.md`, or a line in
   `REVIEW.md`. Don't fix the same issue by hand again and again.

**Done when:** an agent session on this repo runs the checks on its own and
pastes their output before claiming the task is finished.

## Phase 2: On every pull request

1. **Make CI blocking:** lint, typecheck, tests on every target platform, and
   build. The kit doesn't include a CI workflow because CI is project-specific.
   Add one if the repo has none.
2. **PR template:** the installed template asks for Testing, Risk and How to
   revert. Claude can draft the answers; the author is responsible for checking
   them.
3. **AI reviewer, starting on one repo.** Pilot `claude-code-review.yml` (or
   the managed *Code Review for Claude Code* on Team/Enterprise plans, which
   offers Quick, Standard and Deep levels). Tune `REVIEW.md` for 2–3 weeks
   before you copy it to other repos.
   - Add the `ANTHROPIC_API_KEY` (or `CLAUDE_CODE_OAUTH_TOKEN`) repository
     secret.
   - Findings are labelled 🔴 Important, 🟡 Nit or 🟣 Pre-existing, so
     authors aren't penalised for old bugs.
4. **Security review:** `security-review.yml` runs on every PR.
5. **Every review thread must be resolved before merge,** either fixed or
   closed with a one-line reason. This is how false positives are handled.
6. **Make review converge:**
   - Cap review rounds at **3**. After that, the reviewer asks the author to
     rethink the approach instead of filing more comments.
   - After the first round, review **only the new diff** and never re-report a
     finding that was already raised.
   - Name the *class* of bug so the author fixes every instance, not just one
     line.
   - Run extra rounds only on high-risk PRs.

   The workflow prompt already includes these rules.

**Done when:** every PR gets an AI review and a security review, CI blocks
merges, and unresolved threads block merges.

## Phase 3: Approval scaled by risk

The risk tier comes from **what the change touches, not who wrote it**.

| Tier | Typical paths | Requirement |
| --- | --- | --- |
| **Low** | docs, comments, tests only, copy changes | Green CI + AI review clean. The author can merge. |
| **Medium** | ordinary application code | Above + one human approval (the author counts if they are on the trusted list). |
| **High** | auth, billing, installers/updaters, release scripts, CI workflows, secrets handling, data migrations | Above + a CODEOWNER approval from someone *other than* the author, plus a Deep/extra review pass. |

Setup:

1. **Edit `.github/labeler.yml`** so the high-risk globs match this repo. The
   `risk-label` workflow then labels each PR automatically.
2. **Edit `.github/CODEOWNERS`** so high-risk paths, and always
   `.github/workflows/`, need a named human.
3. **Branch protection / ruleset on `main`** (Settings → Rules → Rulesets):
   - Require a pull request before merging
   - Require approvals: 1 (team repos)
   - **Dismiss stale approvals when new commits are pushed.** An approval
     covers one commit.
   - Require review from Code Owners
   - **Require conversation resolution before merging**
   - Require status checks: your CI jobs + `security-review`
   - Block force pushes
4. **Bot approvals never count** as a required human approval. If an agent
   wrote the PR, the person running the agent counts as one of its reviewers.
5. **Start strict, relax with evidence.** Loosen a tier only after its revert
   rate has stayed flat for a few weeks.

### Solo projects

On a repo where you are the only contributor, GitHub won't let you approve
your own PR. Use this variant:

- Required approvals = 0, but keep conversation resolution, required checks
  and Code Owners (which you are) turned on.
- Treat the `risk:high` label as a rule for yourself: read the full diff,
  run it locally, and don't merge it on the same day you wrote it.

## Phase 4: Merge and after merge

1. **Merge queue** (Settings → Rules; available on organization-owned repos)
   so checks run against `main` with the change applied. Two green PRs can
   still produce a broken `main` without one.
2. **Feature flags** for new behaviour. Turning off a flag needs no deploy.
3. **Internal users first, then staged rollout** (for example, a `latest`
   channel first and a `stable` channel after it, or pre-release tags before a
   full release).
4. **One-step revert:** `git revert <sha>` + PR, or GitHub's *Revert* button.
   Every PR template entry says how to undo the change.
5. **"You land it, you own it."** Whoever merged a change fixes it if it
   breaks. Keep PRs small so that's cheap.

## Phase 5: Improve the reviewer continuously

1. **Incidents are the eval set.** Every revert or incident goes into
   `docs/review-evals/incidents.md` with the bad PR, the fix, the exact
   file:line of the bug, and the layer that *should* have caught it.
2. **Re-score the reviewer** against that set every time you change
   `REVIEW.md`, the workflow prompt, its tools **or the model**. Did it now
   catch the known bugs?
3. **For every miss, ask what wasn't in the model's context,** and turn the
   answer into something permanent: a line in `CLAUDE.md` or `REVIEW.md`, a
   skill, a lint rule or a new CI check. Record it in the log's *Fixed at
   source by* column.
4. **Measure noise:** tally each AI comment's outcome (fixed / rejected /
   intentional / didn't matter), and occasionally run the reviewer on
   known-clean PRs. A finding an agent author has to act on costs a whole
   commit and review cycle, so false positives are more expensive than they
   look.
5. **Priorities:** first catch real bugs, second reduce the number of review
   rounds.
6. **Track human effort** (approvals, comments and wait time per PR) against
   the revert and incident rates every month. The goal never changes: less
   human effort per change, with the revert rate no higher than it is now.
7. **Optionally**, run the reviewer on the whole codebase on a schedule
   (nightly or weekly) to find old bugs before new code copies them.

## Phase 6: Auto-merge low-risk changes (only once you have the evidence)

The next step after Phase 5: the owner decides which low-risk changes can
merge on their own once every automated check passes. Turn it on only after
`risk:low` PRs have gone a few weeks with no reverts.

The kit's `risk-label` workflow can do this, but it is **off by default**:

1. Repo Settings → General → turn on **Allow auto-merge**.
2. Settings → Secrets and variables → Actions → **Variables** → add
   `AUTO_MERGE_LOW_RISK` = `true`.

After that, a PR that is *only* `risk:low` (docs-only) and was opened by an
owner, member or collaborator gets auto-merge (squash) turned on. GitHub still
waits for every required check and for every conversation to be resolved. If
your ruleset requires an approval, it also waits for that, so a human stays in
the loop until you decide otherwise. Delete the variable to switch it off.
Widen the definition of `risk:low` in `labeler.yml` only as the evidence
supports it.

## Where humans stay in the loop

- **Should we build this at all?** Vision, taste, goals. Change course early,
  in the thread, rather than with a blocking comment on a finished PR.
- **Dangerous code:** auth, billing, auto-updaters, CI workflows.
- **Architecture,** because those choices set the conventions everyone else
  follows.
- **Checking the evidence:** test output, commands run, screenshots, reviewer
  comments. If you can't say what the checks would miss, it needs a real
  review, not a 👍.
- **Accountability:** a person answers for every change that ships.

## Learning a codebase when machines do the reading

Reading trivial diffs teaches you little. Before changing an unfamiliar area,
ask Claude for an explainer of that exact slice, optionally as a visual page.
It takes minutes and is always up to date.

---

## Rollout checklist (copy into an issue per repo)

- [ ] Phase 0: run `Install-ReviewKit.ps1`; merge any skipped files by hand
- [ ] `CLAUDE.md` filled in with real check commands
- [ ] Format hook calls this project's formatter
- [ ] CI workflow exists and is a required status check
- [ ] API key secret added; AI review and security review run on a test PR
- [ ] `labeler.yml` high-risk globs and `CODEOWNERS` match this repo
- [ ] Branch ruleset: stale-approval dismissal, conversation resolution, code owners
- [ ] Merge queue (org repos) / feature flags / staged release where it applies
- [ ] `incidents.md` started; review the metrics monthly
- [ ] Later, with evidence: turn on low-risk auto-merge (Phase 6)
