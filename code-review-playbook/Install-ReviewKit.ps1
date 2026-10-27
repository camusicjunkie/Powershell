<#
.SYNOPSIS
    Copies the code review kit templates into a repository.

.DESCRIPTION
    Copies ./templates/common plus the folder for the chosen platform into the
    target repository, keeping the same paths. Existing files are skipped (and
    listed) unless -Force is given. The placeholders {{OWNER}} and {{PROJECT}}
    are filled in on the way.

.PARAMETER Path
    Root of the target repository.

.PARAMETER Platform
    GitHub or GitLab. When omitted it is detected from the origin remote URL or
    an existing .gitlab-ci.yml.

.PARAMETER Owner
    User or group for CODEOWNERS, without the leading @ (e.g. my-org/core-team).

.PARAMETER Project
    Project name for the CLAUDE.md heading. Defaults to the target folder name.

.PARAMETER Force
    Overwrite files that already exist.

.EXAMPLE
    ./Install-ReviewKit.ps1 -Path ../my-project -Owner my-github-handle -WhatIf

.EXAMPLE
    ./Install-ReviewKit.ps1 -Path ../work-service -Platform GitLab -Owner my-group/backend
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Path,

    [ValidateSet('GitHub', 'GitLab')]
    [string]$Platform,

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

if (-not $Platform) {
    $remote = if (Get-Command git -ErrorAction SilentlyContinue) { git -C $targetRoot remote get-url origin 2>$null }
    if ($remote -match 'github\.com') { $Platform = 'GitHub' }
    elseif ($remote -match 'gitlab' -or (Test-Path -LiteralPath (Join-Path $targetRoot '.gitlab-ci.yml'))) { $Platform = 'GitLab' }
    else { throw "Couldn't tell whether $targetRoot is on GitHub or GitLab. Pass -Platform GitHub or -Platform GitLab." }
    Write-Host "Detected platform: $Platform"
}

$copied = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()

# -Force so dot-folders (.github, .gitlab, .claude) are included on every platform
$sources = 'common', $Platform.ToLower() | ForEach-Object { Join-Path $templateRoot $_ }
foreach ($file in Get-ChildItem -LiteralPath $sources -Recurse -File -Force) {
    $sourceRoot = $sources | Where-Object { $file.FullName.StartsWith($_) } | Select-Object -First 1
    $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\', '/')
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

if ($Platform -eq 'GitHub') {
    Write-Host @"

Next steps (see code-review-playbook/README.md):
  1. Fill in CLAUDE.md check commands and REVIEW.md focus areas
  2. Point .claude/hooks/format-on-edit.sh at this project's formatter
  3. Adjust high-risk globs in .github/labeler.yml and .github/CODEOWNERS
  4. Add the ANTHROPIC_API_KEY repository secret
  5. Set up the branch ruleset: stale-approval dismissal, conversation resolution, code owners
"@
}
else {
    Write-Host @"

Next steps (see code-review-playbook/GITLAB.md):
  1. Fill in CLAUDE.md check commands and REVIEW.md focus areas
  2. Point .claude/hooks/format-on-edit.sh at this project's formatter
  3. If .gitlab-ci.yml was skipped, add the include and workflow rules from GITLAB.md to it
  4. Adjust .gitlab/risk-tiers.txt and .gitlab/CODEOWNERS
  5. Add masked CI/CD variables ANTHROPIC_API_KEY and GITLAB_REVIEW_TOKEN
  6. Merge request settings: pipelines must succeed, all threads must be resolved
"@
}
