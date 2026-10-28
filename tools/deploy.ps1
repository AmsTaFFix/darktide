<#
.SYNOPSIS
    Copies this repo's mods (and the claude_bridge dev tool) into the Darktide install, and
    optionally asks a running game to reload mods.

.DESCRIPTION
    - Copies mods/<name>/ -> <GameDir>/mods/<name>/ for each mod in -Mods, excluding
      nexus_metadata/ (the same exclusion the release zips use).
    - Copies tools/claude_bridge/ -> <GameDir>/mods/claude_bridge/.
    - Appends any missing mod name to <GameDir>/mods/mod_load_order.txt. That file is Vortex-
      managed and may be rewritten by Vortex later; re-run this script after that happens.
    - Unless -SkipReload is passed, drops a "reload" request for claude_bridge so a running game
      picks up the change without a restart. This only takes effect if claude_bridge is already
      loaded in-game and DMF's developer_mode is enabled.

.PARAMETER GameDir
    Path to the Darktide install (the directory containing bundle\ and mods\).

.PARAMETER Mods
    Mod directory names (relative to mods/) to deploy. Defaults to the repo's three forks plus
    claude_bridge.

.PARAMETER SkipReload
    Don't write a reload request after copying.

.EXAMPLE
    tools/deploy.ps1
    tools/deploy.ps1 -Mods SquadHud -SkipReload
#>

param(
    [string]$GameDir = "C:\Program Files (x86)\Steam\steamapps\common\Warhammer 40,000 DARKTIDE",
    [string[]]$Mods = @("psych_ward", "crosshair_hud", "SquadHud", "claude_bridge"),
    [switch]$SkipReload
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path (Join-Path $GameDir "bundle"))) {
    throw "'$GameDir' doesn't look like a Darktide install (no bundle\ found). Pass -GameDir."
}

$gameModsDir = Join-Path $GameDir "mods"
$loadOrderPath = Join-Path $gameModsDir "mod_load_order.txt"
$appdataBridgeDir = Join-Path $env:APPDATA "Fatshark\Darktide\claude_bridge"

if (-not (Test-Path $appdataBridgeDir)) {
    New-Item -ItemType Directory -Force -Path $appdataBridgeDir | Out-Null
    Write-Host "Created $appdataBridgeDir"
}

foreach ($modName in $Mods) {
    $source = if ($modName -eq "claude_bridge") {
        Join-Path $repoRoot "tools\claude_bridge"
    } else {
        Join-Path $repoRoot "mods\$modName"
    }

    if (-not (Test-Path $source)) {
        Write-Warning "Skipping '$modName': source not found at $source"
        continue
    }

    $destination = Join-Path $gameModsDir $modName

    Write-Host "Deploying $modName -> $destination"
    robocopy $source $destination /E /XD "nexus_metadata" /NFL /NDL /NJH /NJS /NC /NS | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed copying '$modName' (exit code $LASTEXITCODE)"
    }
}

# --- mod_load_order.txt ---------------------------------------------------------------------
# Vortex-managed and may lack a trailing newline; append idempotently.
$existingLines = @()
if (Test-Path $loadOrderPath) {
    $existingLines = Get-Content -Path $loadOrderPath
}

$missing = $Mods | Where-Object { $existingLines -notcontains $_ }
if ($missing.Count -gt 0) {
    $content = (Get-Content -Path $loadOrderPath -Raw -ErrorAction SilentlyContinue)
    if ($null -eq $content) { $content = "" }
    if ($content.Length -gt 0 -and -not $content.EndsWith("`n")) {
        $content += "`r`n"
    }
    $content += ($missing -join "`r`n")
    Set-Content -Path $loadOrderPath -Value $content -NoNewline
    Write-Host "Added to mod_load_order.txt: $($missing -join ', ')"
} else {
    Write-Host "mod_load_order.txt already lists all requested mods"
}

# --- Reload ----------------------------------------------------------------------------------
if (-not $SkipReload) {
    $requestPath = Join-Path $appdataBridgeDir "request.lua"
    $tmpPath = Join-Path $appdataBridgeDir "request.tmp"
    $id = [int][double]::Parse((Get-Date -UFormat %s))

    $requestContent = "return { id = $id, cmd = `"reload`" }`n"
    Set-Content -Path $tmpPath -Value $requestContent -NoNewline
    Move-Item -Path $tmpPath -Destination $requestPath -Force

    Write-Host "Wrote reload request #$id (only takes effect if the game is running, claude_bridge is loaded, and DMF developer_mode is on)"
}

Write-Host "Done."
exit 0
