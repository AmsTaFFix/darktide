<#
.SYNOPSIS
    Starts a new task: opens a GitHub issue and creates a dedicated branch + external sibling
    worktree for it. Step 1-2 of AGENTS.md "Development workflow".

.DESCRIPTION
    - Creates a GitHub issue via `gh issue create` (unless -NoIssue), labeled from -Type.
    - Creates branch <Type>/<Topic> in a new worktree at ../darktide-wt/<Type>-<Topic>
      (a sibling of this repo), based on main.
    - Prints the worktree path and next steps.

.PARAMETER Type
    feat | fix | chore. Drives the branch prefix and the issue label.

.PARAMETER Topic
    kebab-case slug for the branch/worktree, e.g. havoc-button.

.PARAMETER Title
    Issue title (the user-visible outcome). Required unless -NoIssue.

.PARAMETER Body
    Optional issue body.

.PARAMETER NoIssue
    Skip issue creation; just make the branch + worktree.

.EXAMPLE
    tools/new-task.ps1 -Type feat -Topic havoc-button -Title "Add a Havoc quick-launch button"
    tools/new-task.ps1 -Type fix -Topic resync-crash -Title "Fix resync crash" -NoIssue
#>

param(
    [Parameter(Mandatory)][ValidateSet("feat", "fix", "chore")][string]$Type,
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9]+(-[a-z0-9]+)*$')][string]$Topic,
    [string]$Title,
    [string]$Body = "",
    [switch]$NoIssue
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$branch = "$Type/$Topic"
$wtRoot = Join-Path (Split-Path -Parent $repoRoot) "darktide-wt"
$wtPath = Join-Path $wtRoot "$Type-$Topic"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "gh CLI not found on PATH. Install it or run the raw git/gh commands from AGENTS.md."
}
if (Test-Path $wtPath) {
    throw "Worktree path already exists: $wtPath"
}

# --- Issue ------------------------------------------------------------------------------------
if (-not $NoIssue) {
    if (-not $Title) { throw "-Title is required unless -NoIssue is passed." }
    $label = switch ($Type) {
        "feat"  { "enhancement" }
        "fix"   { "bug" }
        default { $null }
    }
    $ghArgs = @("issue", "create", "--title", $Title, "--body", $Body)
    if ($label) { $ghArgs += @("--label", $label) }

    Write-Host "Creating issue: $Title"
    $issueUrl = (& gh @ghArgs).Trim()
    if ($LASTEXITCODE -ne 0) { throw "gh issue create failed (exit $LASTEXITCODE)." }
    $issueNumber = ($issueUrl -split "/")[-1]
    Write-Host "Opened issue #$issueNumber  $issueUrl"
} else {
    $issueNumber = $null
    Write-Host "Skipping issue creation (-NoIssue)."
}

# --- Worktree + branch ------------------------------------------------------------------------
if (-not (Test-Path $wtRoot)) {
    New-Item -ItemType Directory -Force -Path $wtRoot | Out-Null
}

Write-Host "Creating worktree $branch -> $wtPath"
& git -C $repoRoot worktree add -b $branch $wtPath main
if ($LASTEXITCODE -ne 0) { throw "git worktree add failed (exit $LASTEXITCODE)." }

Write-Host ""
Write-Host "Ready. Next:"
Write-Host "  cd `"$wtPath`""
Write-Host "  # implement, then verify on a live client (tools/deploy.ps1 + Claude Bridge)"
if ($issueNumber) {
    Write-Host "  tools/finish-task.ps1 -Issue $issueNumber [-Verified]"
} else {
    Write-Host "  tools/finish-task.ps1 [-Issue <N>] [-Verified]"
}
exit 0
