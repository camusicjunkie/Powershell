#!/usr/bin/env bash
# Runs after Claude edits a file: formats it and lints it, so the agent sees
# lint errors right away instead of in review.
# Reads the hook payload (JSON) on stdin. Exit code 2 sends stderr back to Claude.
# Delete the branches for languages this repo doesn't use; add the ones it does.

set -u
file=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -n "$file" ] && [ -f "$file" ] || exit 0

has() { command -v "$1" >/dev/null 2>&1; }
out=""

case "$file" in
  *.ps1|*.psm1|*.psd1)
    if has pwsh; then
      out=$(pwsh -NoProfile -Command "
        if (Get-Module -ListAvailable PSScriptAnalyzer) {
          \$p = '$file'
          Invoke-Formatter -ScriptDefinition (Get-Content -Raw \$p) | Set-Content -NoNewline \$p
          Invoke-ScriptAnalyzer -Path \$p -Severity Warning,Error | Format-Table -AutoSize | Out-String -Width 200
        }" 2>&1)
    fi ;;
  *.js|*.jsx|*.ts|*.tsx|*.json|*.css|*.md|*.yml|*.yaml)
    has npx && npx --no-install prettier --write "$file" >/dev/null 2>&1
    case "$file" in *.js|*.jsx|*.ts|*.tsx)
      has npx && out=$(npx --no-install eslint "$file" 2>&1) ;;
    esac ;;
  *.py)
    has ruff && { ruff format "$file" >/dev/null 2>&1; out=$(ruff check "$file" 2>&1) || true; } ;;
  *.go)
    has gofmt && gofmt -w "$file" ;;
  *.sh)
    has shellcheck && out=$(shellcheck "$file" 2>&1) ;;
esac

# Only report real findings back to Claude.
if [ -n "$(printf '%s' "$out" | tr -d '[:space:]')" ] && ! printf '%s' "$out" | grep -qiE '^\s*All checks passed!?\s*$'; then
  printf 'Lint findings in %s:\n%s\n' "$file" "$out" >&2
  exit 2
fi
exit 0
