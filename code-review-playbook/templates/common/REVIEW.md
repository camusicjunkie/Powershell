# Review guidelines

<!-- Code owners: say here what matters in your part of the code. Keep it brief.
     When the reviewer keeps flagging the same thing, fix it at the source
     (lint rule, CLAUDE.md, this file) instead of by hand. -->

## What counts as a failure here
Report only problems that would make the project wrong for its users, such as:
- Incorrect behaviour, crashes, data loss or corruption
- Security issues: injection, secrets in code or logs, unsafe deserialization, missing auth checks
- Docs or help text that lie about what the code does
- Config that misroutes (wrong environment, endpoint, path or permission)
- Breaking changes to public interfaces without a note in the PR
- A bug fix that patches the symptom instead of the root cause

## Don't report
- Style, formatting or naming preferences already covered by linters
- Speculative refactors and "consider" suggestions
- Problems in code this PR didn't change. If something pre-existing is serious, mark it 🟣 Pre-existing.

## Ignored paths
- `**/*.lock`, generated files, vendored code, build output
- (add more)

## High-risk areas (read the whole change, not just the diff)
- (auth, billing, installers/updaters, release scripts, `.github/workflows/`)

## Output format
- Every finding cites an exact `path:line` that exists in the diff or repo. Never guess filenames.
- Mark each finding 🔴 Important, 🟡 Nit or 🟣 Pre-existing, and list them most severe first.
- When a finding is one of a class, name the class and list every instance, so the author fixes them all at once.
- Start with a one-line summary giving the number of findings, or say clearly **"No issues found."**
