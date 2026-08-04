<#
.SYNOPSIS
    Appends a release entry to a script's manifest and bumps its fxmanifest.lua.

.DESCRIPTION
    The two halves of a release have to agree: the `version '...'` line in the
    resource's fxmanifest.lua and the newest entry in <script>.json here. Doing
    it by hand is where they drift apart, so this does both in one step.

    Nothing is committed or pushed — review the diff, then commit yourself.

.EXAMPLE
    .\tools\new-release.ps1 -Name fx-stash -Version 1.1.0 `
        -Changelog "Shared stash member limit is now configurable." `
        -UpdateFiles server/members.lua, config.lua, fxmanifest.lua

.EXAMPLE
    # Security fix: -Critical adds the red [CRITICAL] tag in the server console.
    .\tools\new-release.ps1 -Name fx-admin -Version 1.0.1 -Critical `
        -Changelog "Fixed a permission bypass in the teleport command." `
        -UpdateFiles server/permissions.lua
#>
[CmdletBinding()]
param(
    # Manifest name without .json — matches SCRIPT_ID in the resource's versionchecker.lua.
    [Parameter(Mandatory = $true)]
    [string] $Name,

    [Parameter(Mandatory = $true)]
    [string] $Version,

    # One string per bullet shown in the server console.
    [Parameter(Mandatory = $true)]
    [string[]] $Changelog,

    # Files the customer has to replace. Merged across every release they are behind.
    [string[]] $UpdateFiles = @(),

    # Adds the red [CRITICAL] tag. Use for security fixes.
    [switch] $Critical,

    [string] $Date,

    # Resource folder whose fxmanifest.lua gets the version bump. Defaults to a
    # sibling folder named $Name next to the repo; pass -SkipManifest to skip.
    [string] $ResourcePath,

    [switch] $SkipManifest
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_json.ps1')

$repoRoot    = Split-Path $PSScriptRoot -Parent
$manifestJson = Join-Path $repoRoot "$Name.json"

if (-not (Test-Path $manifestJson)) {
    throw "$Name.json not found. New script? Use tools\add-script.ps1 instead."
}

if (-not $Date) { $Date = Get-Date -Format 'yyyy-MM-dd' }

# ---------------------------------------------------------------- read + validate
# ConvertFrom-Json on 5.1 hands back the JSON array as ONE pipeline object, so a
# plain @(...) wrap nests it instead of flattening it — and then $entry below is
# the whole array rather than a release. Enumerate it explicitly.
$parsed = Get-Content $manifestJson -Raw -Encoding UTF8 | ConvertFrom-Json
$existing = New-Object System.Collections.ArrayList
foreach ($entry in $parsed) { [void] $existing.Add($entry) }

foreach ($entry in $existing) {
    if ($entry.version -eq $Version) {
        throw "$Name.json already has a $Version entry."
    }
}

$latest = $null
foreach ($entry in $existing) {
    if ($null -eq $latest) {
        $latest = $entry.version
    } elseif ((Compare-ResourceVersion $entry.version $latest) -gt 0) {
        $latest = $entry.version
    }
}

if ($latest -and (Compare-ResourceVersion $Version $latest) -lt 0) {
    Write-Warning "$Version is older than the current latest ($latest). The checker sorts numerically, so $latest stays the latest release."
}

# ---------------------------------------------------------------- write the manifest
$release = [ordered] @{
    version     = $Version
    date        = $Date
    critical    = [bool] $Critical
    changelog   = $Changelog
    updateFiles = $UpdateFiles
}

$all = @()
foreach ($entry in $existing) { $all += $entry }
$all += [pscustomobject] $release

Write-Utf8NoBom -Path $manifestJson -Text (ConvertTo-ManifestJson $all)
Write-Host "updated  $Name.json  (+ $Version)" -ForegroundColor Green

# ---------------------------------------------------------------- bump fxmanifest.lua
if ($SkipManifest) {
    Write-Host "skipped  fxmanifest.lua bump (-SkipManifest)" -ForegroundColor DarkGray
    return
}

if (-not $ResourcePath) {
    $ResourcePath = Join-Path (Split-Path $repoRoot -Parent) $Name
}

$fxmanifest = Join-Path $ResourcePath 'fxmanifest.lua'
if (-not (Test-Path $fxmanifest)) {
    Write-Warning "fxmanifest.lua not found at $fxmanifest - bump the version there by hand, or re-run with -ResourcePath."
    return
}

$old = Set-ManifestVersion -ManifestPath $fxmanifest -Version $Version
Write-Host "updated  $fxmanifest  ($old -> $Version)" -ForegroundColor Green
Write-Host ""
Write-Host "Review the diff, then commit and push:" -ForegroundColor Cyan
Write-Host "  git -C `"$repoRoot`" add $Name.json"
Write-Host "  git -C `"$repoRoot`" commit -m `"$Name`: add $Version release entry`""
Write-Host "  git -C `"$repoRoot`" push"
Write-Host ""
Write-Host "raw.githubusercontent.com caches for ~5 minutes, so servers pick it up shortly after." -ForegroundColor DarkGray
