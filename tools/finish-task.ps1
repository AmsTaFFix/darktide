<#
.SYNOPSIS
    Finishes a task: pushes the current worktree branch, opens a PR, and — only if the change was
    verified on a live client — merges it and cleans up the worktree. Step 4-5 of AGENTS.md
    "Development workflow". Run from inside the task worktree.

.DESCRIPTION
    - Pushes the current branch to origin.
    - Opens a PR (unless one already exists) with "Closes #<Issue>" and the Claude Code
      attribution line in the body.
    - Verification gate:
        -Verified      -> merges with a non-ff merge commit (gh pr merge --merge --delete-branch)
                          and removes this worktree.
        (not set)      -> stops at the open PR and reports that live-client verification is
                          missing, so the user must decide whether to merge.

.PARAMETER Issue
    Issue number to close (adds "Closes #N" to a newly created PR body).

.PARAMETER Title
    PR title. Defaults to the subject of the latest commit.

.PARAMETER Verified
    The change was verified on a live Darktide client. Merges the PR and cleans up.

.PARAMETER NoMerge
    Even with -Verified, open the PR but don't merge (leave it for review).

.EXAMPLE
    tools/finish-task.ps1 -Issue 7 -Verified
    tools/finish-task.ps1 -Issue 7          # not verified: opens PR, asks the user to decide
#>

param(
    [int]$Issue,
    [string]$Title,
    [switch]$Verified,
    [switch]$NoMerge
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "gh CLI not found on PATH."
}

$branch = (& git rev-parse --abbrev-ref HEAD).Trim()
$worktree = (& git rev-parse --show-toplevel).Trim()
if ($branch -eq "main") {
    throw "On 'main'. Run this from inside a task worktree, not the main checkout."
}

# --- Push -------------------------------------------------------------------------------------
Write-Host "Pushing $branch -> origin"
& git push -u origin $branch
if ($LASTEXITCODE -ne 0) { throw "git push failed (exit $LASTEXITCODE)." }

# --- PR (create only if absent) ---------------------------------------------------------------
$existingPr = (& gh pr view $branch --json url --jq ".url" 2>$null)
if ($LASTEXITCODE -eq 0 -and $existingPr) {
    $prUrl = $existingPr.Trim()
    Write-Host "PR already exists: $prUrl"
} else {
    if (-not $Title) { $Title = (& git log -1 --pretty=%s).Trim() }
    $bodyLines = @()
    if ($Issue) { $bodyLines += "Closes #$Issue"; $bodyLines += "" }
    $bodyLines += "🤖 Generated with [Claude Code](https://claude.com/claude-code)"
    $body = $bodyLines -join "`n"

    Write-Host "Creating PR: $Title"
    $prUrl = (& gh pr create --base main --head $branch --title $Title --body $body).Trim()
    if ($LASTEXITCODE -ne 0) { throw "gh pr create failed (exit $LASTEXITCODE)." }
    Write-Host "Opened PR: $prUrl"
}

# --- Gate -------------------------------------------------------------------------------------
if (-not $Verified) {
    Write-Host ""
    Write-Host "NOT verified on a live client. PR left open on purpose."
    Write-Host "Decide: verify + re-run with -Verified, or merge manually if you accept the risk."
    exit 0
}
if ($NoMerge) {
    Write-Host "-Verified but -NoMerge: leaving the PR open for review."
    exit 0
}

Write-Host "Verified. Merging (non-ff) and cleaning up."
& gh pr merge $branch --merge --delete-branch
if ($LASTEXITCODE -ne 0) { throw "gh pr merge failed (exit $LASTEXITCODE)." }

# Leave the worktree before removing it, then prune.
$mainRoot = Split-Path -Parent ((& git rev-parse --path-format=absolute --git-common-dir).Trim())
Set-Location $mainRoot
& git worktree remove $worktree
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Merged, but couldn't remove worktree '$worktree'. Remove it manually: git worktree remove `"$worktree`""
    exit 0
}
Write-Host "Merged and worktree removed."
exit 0
