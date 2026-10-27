# Code Review Playbook: GitLab edition

The plan in [README.md](README.md) applies unchanged: the same layers, metrics
and phases. This page covers what is different on GitLab: which files the kit
installs, the settings to turn on, and which features need a paid tier.
It works on GitLab.com and on self-managed GitLab, because the scripts use the
`CI_API_V4_URL` that the runner provides.

## GitLab tiers at a glance

| Feature | Free | Premium / Ultimate |
| --- | :---: | :---: |
| MR template, protected branches, auto-merge, revert button, feature flags | ✅ | ✅ |
| **Pipelines must succeed**, **All threads must be resolved** | ✅ | ✅ |
| AI review, security review, risk labels (this kit) | ✅ | ✅ |
| Required approval rules, *prevent approval by author*, *remove approvals when commits are added* | – | ✅ |
| Code Owners and required code owner approval | – | ✅ |
| Merge trains (the merge queue) | – | ✅ |
| Scoped labels (`risk::low` as mutually exclusive) | plain labels | ✅ |
| Project access tokens on GitLab.com | – (use a bot user's PAT) | ✅ |

On Free, follow the **Solo projects** variant in README Phase 3: blocking CI and
resolved threads do the gating, and you treat `risk::high` as a rule for yourself.

## Phase 0: Install

```powershell
./code-review-playbook/Install-ReviewKit.ps1 -Path ../work-service -Platform GitLab -Owner my-group/backend
```

| File | Purpose |
| --- | --- |
| `CLAUDE.md`, `REVIEW.md`, `.claude/`, `docs/review-evals/incidents.md` | Same as on GitHub (see README). |
| `.gitlab/merge_request_templates/Default.md` | Testing / Risk / How to revert. GitLab uses a template called `Default` automatically. |
| `.gitlab/CODEOWNERS` | Sections with required approval counts (Premium). |
| `.gitlab/risk-tiers.txt` | Globs that decide the `risk::low`, `risk::medium` or `risk::high` label. |
| `.gitlab/ci/claude-review.gitlab-ci.yml` | The `claude-code-review`, `claude-security-review` and `risk-tier` jobs. |
| `.gitlab/ci/scripts/*.py` | The scripts those jobs run. Standard library only, so no `pip install`. |
| `.gitlab-ci.yml` | Installed **only if the project has none**. Contains the include and workflow rules shown below. |

### If the project already has a `.gitlab-ci.yml`

The installer skips it. Add these two blocks to your existing file yourself:

```yaml
include:
  - local: .gitlab/ci/claude-review.gitlab-ci.yml

# Use merge request pipelines while an MR is open, branch pipelines otherwise.
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH
```

The `workflow` block matters. Without it, the review jobs run in a separate
merge request pipeline next to your branch pipeline, and **Pipelines must
succeed** only looks at the newest one. Your tests could fail while the MR
still shows green. If you already have `workflow: rules`, make sure they allow
`merge_request_event` pipelines. The kit's jobs use `stage: test`, so that
stage must exist (it is one of GitLab's default stages).

## Phase 1: Before the merge request

Nothing changes here. `CLAUDE.md`, the format hook, and `/code-review` plus
`/security-review` in Claude Code work the same with any git host.

## Phase 2: On every merge request

1. **CI/CD variables** (Settings → CI/CD → Variables). Make them **Masked**,
   but **not Protected**, because MR pipelines run on unprotected branches:
   - `ANTHROPIC_API_KEY`
   - `GITLAB_REVIEW_TOKEN`: a project access token (Settings → Access tokens)
     with role **Developer** and scope **api**. On GitLab.com Free, use a
     personal access token from a dedicated bot user instead. The reviewer
     posts as this token's user.
2. **Merge request settings** (Settings → Merge requests):
   - ✅ **Pipelines must succeed**
   - ✅ **All threads must be resolved.** Every finding is a thread, so this
     makes AI and security findings block the merge until they are fixed or
     resolved with a reason.
   - Pipelines settings: keep *Auto-cancel redundant pipelines* on, so a new
     push cancels the review of the previous commit.
3. **Your own CI checks** (lint, tests, build) go in `.gitlab-ci.yml` and must
   **not** be `allow_failure`. The kit's review jobs are `allow_failure: true`
   on purpose: a Claude API outage shouldn't block merging, and their threads
   do the blocking.
4. **What the reviewer does on each push:**
   - `claude-code-review` and `claude-security-review` run Claude Code headless
     with read-only tools (Read, Grep, Glob and read-only `git` commands).
   - Findings are posted as threads labelled 🔴 Important, 🟡 Nit or
     🟣 Pre-existing, inline on the line when GitLab accepts that position,
     otherwise as an MR-level thread that quotes `path:line`. Findings that
     point at files that don't exist are dropped.
   - Each round ends with a summary note giving the number of findings, or
     saying **"No issues found."**
   - **Convergence:** a round never re-reports earlier findings. After the
     first round it reviews only the commits pushed since the last round.
     After `REVIEW_MAX_ROUNDS` (default 3) it reports only 🔴 findings and asks
     the author to rethink the approach.
5. **Optional extra scanners:** GitLab's SAST and Secret Detection templates
   are free. Uncomment them at the bottom of `claude-review.gitlab-ci.yml`.
6. **Pilot on one project** for 2–3 weeks and tune `REVIEW.md` before you roll
   it out to others.

## Phase 3: Approval scaled by risk

1. **Edit `.gitlab/risk-tiers.txt`.** Any file matching `[high]` makes the MR
   high risk. The MR is low risk only if *every* file matches `[low]`.
   Everything else is medium. The `risk-tier` job sets exactly one of the
   labels `risk::low`, `risk::medium` or `risk::high`.
2. **Protected branch** (Settings → Repository → Protected branches) for the
   default branch: *Allowed to push and merge* = No one, *Allowed to merge* =
   Maintainers or Developers. Turn on **Code owner approval** (Premium).
3. **Approval settings** (Premium, Settings → Merge requests → Approvals):
   - An approval rule requiring 1 approval for the default branch
   - ✅ Prevent approval by author
   - ✅ Prevent approvals by users who add commits. This also covers the
     person running an agent that pushes to the MR.
   - ✅ **Remove all approvals when commits are added.** An approval covers
     one commit.
4. **`.gitlab/CODEOWNERS`:** keep `.gitlab-ci.yml`, `.gitlab/` and `.claude/`
   in a section with a required approval count, and add sections for auth,
   billing, installers and release code.
5. **Bot approvals never count.** Don't add the review token's user to any
   approval rule.

## Phase 4: Merge and after merge

| Article | GitLab feature |
| --- | --- |
| Merge queue | **Merge trains** (Premium): Settings → Merge requests → *Enable merged results pipelines* + *Enable merge trains*. |
| Feature flags | **Deploy → Feature flags** (Unleash-compatible, all tiers), or your own flag service. |
| Internal users first, staged rollout | Environments with manual `when: manual` promotion jobs, or flag strategies by user list or percentage. |
| One-step revert | The **Revert** button on a merged MR creates a revert MR. |

## Phase 5: Improve the reviewer

The same as README Phase 5. To re-score the reviewer against an old MR from
your incident log, run the job's script locally from a checkout of the bad
commit, using the same variables. Use a test project for that, because the
script posts to whichever MR `CI_MERGE_REQUEST_IID` points at.

## Phase 6: Auto-merge low-risk changes

Off by default. To turn it on, add the CI/CD variable `AUTO_MERGE_LOW_RISK` =
`true`. When an MR is `risk::low` and its author has at least Developer access
to the project (`TRUSTED_ACCESS_LEVEL`, default 30), the `risk-tier` job sets
it to **auto-merge**. GitLab then waits for the pipeline, resolved threads and
any required approvals. If a later push raises the tier, the job cancels the
auto-merge it set. It never cancels one a person set. The token's user needs
permission to merge into the target branch.

## Security notes

- Anyone who can push a branch can change these CI files and scripts in their
  MR, and so can read the two variables. That is true of any GitLab CI
  variable that isn't protected. Keep the token at Developer role with the
  `api` scope, and rotate it on a schedule.
- Fork MRs run in the fork's project and don't receive your variables. The
  review jobs then exit with a message.
- The reviewer only gets read-only tools, which limits what a prompt hidden
  in a malicious diff could make it do.
