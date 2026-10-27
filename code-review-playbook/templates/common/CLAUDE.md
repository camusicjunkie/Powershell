# {{PROJECT}}

<!-- Keep this file short: it is loaded into every session and every review.
     Link to longer docs instead of inlining them. -->

## What this is
One or two sentences: what the project does and who uses it.

## Stack
- Language / runtime:
- Key libraries:
- Build / package tool:

## Conventions
- (naming, error handling, logging, file layout: only the rules people actually break)

## Non-goals
- (things we deliberately do not do, so nobody "helpfully" adds them)

## Verify before you say "done"
Run these checks and **paste their output**. Don't just say they pass.
1. Build: `<command>`
2. Tests: `<command>`
3. Lint / format: `<command>`
4. UI changes: screenshot the result and compare it with the design or the previous behaviour.

Then review your own diff with fresh context (`/code-review`, and `/security-review`
for anything touching input handling, auth, secrets or CI) before opening a PR.

## Pull requests
- Keep PRs small and single-purpose.
- Fill in every section of the PR/MR template, including **How to revert**.
- Changes to the high-risk areas listed in `REVIEW.md` need a human code owner's review.

## More docs
- `REVIEW.md`: what reviewers focus on
- `docs/`: architecture and design notes
