<#
.SYNOPSIS
    Copies the code review kit templates into a repository.

.DESCRIPTION
    Copies everything under ./templates into the target repository, keeping the
    same paths. Existing files are skipped (and listed) unless -Force is given.
    The placeholders {{OWNER}} and {{PROJECT}} are filled in on the way.

.PARAMETER Path
    Root of the target repository.

.PARAMETER Owner
    GitHub user or team for CODEOWNERS, without the leading @ (e.g. my-org/core-team).

.PARAMETER Project
    Project name for the CLAUDE.md heading. Defaults to the target folder name.

.PARAMETER Force
    Overwrite files that already exist.

.EXAMPLE
    ./Install-ReviewKit.ps1 -Path ../my-project -Owner my-github-handle -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$Owner,

    [string]$Project,

    [switch]$Force
)

$templateRoot = Join-Path $PSScriptRoot 'templates'
$targetRoot = (Resolve-Path -LiteralPath $Path).ProviderPath
if (-not $Project) { $Project = Split-Path $targetRoot -Leaf }
$Owner = $Owner.TrimStart('@')

if (-not (Test-Path -LiteralPath (Join-Path $targetRoot '.git'))) {
    Write-Warning "$targetRoot is not the root of a git repository."
}

$copied = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()

# -Force so dot-folders (.github, .claude) are included on every platform
foreach ($file in Get-ChildItem -LiteralPath $templateRoot -Recurse -File -Force) {
    $relative = $file.FullName.Substring($templateRoot.Length).TrimStart('\', '/')
    $destination = Join-Path $targetRoot $relative

    if ((Test-Path -LiteralPath $destination) -and -not $Force) {
        $skipped.Add($relative)
        continue
    }

    if ($PSCmdlet.ShouldProcess($destination, 'Write template')) {
        $folder = Split-Path $destination -Parent
        if (-not (Test-Path -LiteralPath $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }

        $content = [System.IO.File]::ReadAllText($file.FullName)
        $content = $content.Replace('{{OWNER}}', $Owner).Replace('{{PROJECT}}', $Project)
        # UTF-8 without BOM and LF line endings, so the hook script runs under bash
        $content = $content -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($destination, $content, [System.Text.UTF8Encoding]::new($false))
        $copied.Add($relative)
    }
}

if ($copied.Count) {
    Write-Host "Installed $($copied.Count) file(s):" -ForegroundColor Green
    $copied | ForEach-Object { Write-Host "  $_" }
}
if ($skipped.Count) {
    Write-Host "Skipped $($skipped.Count) existing file(s). Merge these by hand or re-run with -Force:" -ForegroundColor Yellow
    $skipped | ForEach-Object { Write-Host "  $_" }
}

Write-Host @"

Next steps (see code-review-playbook/README.md):
  1. Fill in CLAUDE.md check commands and REVIEW.md focus areas
  2. Point .claude/hooks/format-on-edit.sh at this project's formatter
  3. Adjust high-risk globs in .github/labeler.yml and .github/CODEOWNERS
  4. Add the ANTHROPIC_API_KEY repository secret
  5. Set up the branch ruleset: stale-approval dismissal, conversation resolution, code owners
"@
