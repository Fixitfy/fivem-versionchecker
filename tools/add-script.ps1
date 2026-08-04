<#
.SYNOPSIS
    Onboards a new resource: writes its versionchecker.lua and its first manifest.

.DESCRIPTION
    Renders _template/versionchecker.lua into the resource, creates <Name>.json
    with a 1.0.0 entry, and prints the two lines you still have to add by hand.

    The fxmanifest.lua and config.lua edits are deliberately NOT automated: every
    resource orders its server_scripts differently, and a script that guesses
    where to splice a line into someone else's load order is a script that
    silently breaks it. The exact lines to paste are printed at the end.

.EXAMPLE
    .\tools\add-script.ps1 -Name fx-garage `
        -ResourcePath "..\fx-garage" `
        -Description "advanced garage system (QBCore / Qbox / ESX)."

.EXAMPLE
    # Resource with no server/ folder, and a config living somewhere else.
    .\tools\add-script.ps1 -Name fx-tuning -ResourcePath "..\fx-tuning" `
        -TargetFile "versionchecker.lua" -ConfigFile "shared/config.lua" `
        -Description "vehicle tuning shop."
#>
[CmdletBinding()]
param(
    # Manifest name without .json. Becomes SCRIPT_ID in the generated file.
    [Parameter(Mandatory = $true)]
    [string] $Name,

    [Parameter(Mandatory = $true)]
    [string] $ResourcePath,

    # Tail of the changelog line: "First public release of <Name> - <Description>"
    [Parameter(Mandatory = $true)]
    [string] $Description,

    # Where versionchecker.lua goes inside the resource. Match the resource's own
    # layout: server/ for most, s/ for fx-hud, the root for flat resources.
    [string] $TargetFile = 'server/versionchecker.lua',

    # Config file holding Config.VersionCheck, named in the generated header comment.
    [string] $ConfigFile = 'config.lua',

    [string] $Version = '1.0.0',

    [string] $Date
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_json.ps1')

$repoRoot = Split-Path $PSScriptRoot -Parent
$template = Join-Path $repoRoot '_template\versionchecker.lua'
$jsonPath = Join-Path $repoRoot "$Name.json"

if (-not (Test-Path $template))     { throw "template missing: $template" }
if (-not (Test-Path $ResourcePath)) { throw "resource folder not found: $ResourcePath" }
if (Test-Path $jsonPath)            { throw "$Name.json already exists. Use tools\new-release.ps1 to add a release." }

if (-not $Date) { $Date = Get-Date -Format 'yyyy-MM-dd' }

# ---------------------------------------------------------------- versionchecker.lua
$luaPath = Join-Path $ResourcePath $TargetFile
$luaDir  = Split-Path $luaPath -Parent
if (-not (Test-Path $luaDir)) {
    New-Item -ItemType Directory -Force -Path $luaDir | Out-Null
}
if (Test-Path $luaPath) {
    throw "$luaPath already exists - delete it first if you meant to regenerate it."
}

$lua = [System.IO.File]::ReadAllText($template)
$lua = $lua.Replace('__NAME__', $Name).Replace('__CONFIG__', $ConfigFile)
Write-Utf8NoBom -Path $luaPath -Text $lua
Write-Host "created  $luaPath" -ForegroundColor Green

# ---------------------------------------------------------------- <Name>.json
$release = [pscustomobject] @{
    version     = $Version
    date        = $Date
    critical    = $false
    changelog   = @("First public release of $Name " + [char] 0x2014 + " $Description")
    updateFiles = @()
}

Write-Utf8NoBom -Path $jsonPath -Text (ConvertTo-ManifestJson @($release))
Write-Host "created  $jsonPath" -ForegroundColor Green

# ---------------------------------------------------------------- what is left by hand
$fxmanifest = Join-Path $ResourcePath 'fxmanifest.lua'
$quote = "'"
if (Test-Path $fxmanifest) {
    $text = [System.IO.File]::ReadAllText($fxmanifest)
    # Match the quote style the file already uses for its version line.
    if ($text -match '(?m)^\s*version\s*"') { $quote = '"' }

    $current = [regex]::Match($text, "(?m)^\s*version\s*['`"]([^'`"]*)")
    if ($current.Success -and $current.Groups[1].Value -ne $Version) {
        Write-Warning "fxmanifest.lua says version $($current.Groups[1].Value) but the manifest entry is $Version - they must match."
    }
}

Write-Host ""
Write-Host "Three edits left, by hand:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. $fxmanifest -> server_scripts, right after '@oxmysql/lib/MySQL.lua':"
Write-Host "       $quote$TargetFile$quote," -ForegroundColor Yellow
Write-Host "     (If server_scripts already globs the folder, e.g. 'server/*.lua', skip this"
Write-Host "      line - listing it as well loads the file twice.)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  2. Same file, the version line:"
Write-Host "       version $quote$Version$quote" -ForegroundColor Yellow
Write-Host ""
Write-Host "  3. $(Join-Path $ResourcePath $ConfigFile):"
Write-Host "       Config.VersionCheck = true" -ForegroundColor Yellow
Write-Host ""
Write-Host "Then add the row to README.md and push." -ForegroundColor Cyan
