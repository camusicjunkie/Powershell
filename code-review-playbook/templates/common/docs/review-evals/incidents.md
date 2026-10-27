# Incident and revert log (reviewer eval set)

Every revert, hotfix or incident gets a row here. Each time you change the review
setup (REVIEW.md, the workflow prompt, its tools, the model or the review level),
re-run the reviewer on these PRs and check whether it now flags the recorded bug.

For every miss, ask what wasn't in the model's context, and fix that at the source.

| Date | Bad PR | Fix / revert PR | Bug location (path:line) | What went wrong | Layer that should have caught it | Fixed at source by (CLAUDE.md / REVIEW.md / skill / lint / CI check) | Reviewer catches it now? |
| --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | pre-PR / AI review / security / CI / human / rollout | | |

## Monthly metrics

| Month | PRs merged | Reverts | Incidents | Human approvals / PR (median, p95) | Human comments / PR | Median wait on a human | Median review rounds | AI findings: fixed / rejected / intentional / didn't matter |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | |
