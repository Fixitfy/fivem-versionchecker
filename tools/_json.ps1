# Shared JSON renderer for the release-manifest tools.
#
# ConvertTo-Json in Windows PowerShell 5.1 indents with 4 spaces and escapes
# non-ASCII to \uXXXX, which would rewrite every existing manifest the moment a
# tool touches it. These helpers emit the repo's own style instead: 2-space
# indent, literal UTF-8, and no BOM.

function ConvertTo-JsonStringLiteral {
    param([string] $Value)

    $sb = New-Object System.Text.StringBuilder
    [void] $sb.Append('"')
    foreach ($ch in $Value.ToCharArray()) {
        switch ([string] $ch) {
            '"'      { [void] $sb.Append('\"');  continue }
            '\'      { [void] $sb.Append('\\');  continue }
            "`b"     { [void] $sb.Append('\b');  continue }
            "`f"     { [void] $sb.Append('\f');  continue }
            "`n"     { [void] $sb.Append('\n');  continue }
            "`r"     { [void] $sb.Append('\r');  continue }
            "`t"     { [void] $sb.Append('\t');  continue }
            default {
                if ([int] $ch -lt 0x20) {
                    [void] $sb.AppendFormat('\u{0:x4}', [int] $ch)
                } else {
                    [void] $sb.Append($ch)
                }
            }
        }
    }
    [void] $sb.Append('"')
    return $sb.ToString()
}

# Renders one release object. $Release is a hashtable/PSCustomObject with the
# keys version, date, critical, changelog, updateFiles. Fields are emitted in a
# fixed order so diffs stay readable; empty optional fields are omitted, except
# updateFiles which stays as [] to match the existing manifests.
function ConvertTo-ReleaseJson {
    param($Release)

    $lines = New-Object System.Collections.ArrayList
    [void] $lines.Add('  {')

    $fields = New-Object System.Collections.ArrayList
    [void] $fields.Add('    "version": ' + (ConvertTo-JsonStringLiteral $Release.version))

    if ($Release.date) {
        [void] $fields.Add('    "date": ' + (ConvertTo-JsonStringLiteral $Release.date))
    }
    if ($Release.critical) {
        [void] $fields.Add('    "critical": true')
    }

    $changelog = @($Release.changelog)
    if ($changelog.Count -gt 0) {
        $entry = "    `"changelog`": [`n"
        $items = @()
        foreach ($line in $changelog) {
            $items += '      ' + (ConvertTo-JsonStringLiteral $line)
        }
        $entry += ($items -join ",`n") + "`n    ]"
        [void] $fields.Add($entry)
    }

    $updateFiles = @($Release.updateFiles)
    if ($updateFiles.Count -gt 0) {
        $entry = "    `"updateFiles`": [`n"
        $items = @()
        foreach ($file in $updateFiles) {
            $items += '      ' + (ConvertTo-JsonStringLiteral $file)
        }
        $entry += ($items -join ",`n") + "`n    ]"
        [void] $fields.Add($entry)
    } else {
        [void] $fields.Add('    "updateFiles": []')
    }

    [void] $lines.Add(($fields -join ",`n"))
    [void] $lines.Add('  }')
    return ($lines -join "`n")
}

# Renders the whole manifest: a JSON array of release objects.
function ConvertTo-ManifestJson {
    param($Releases)

    $blocks = @()
    foreach ($release in @($Releases)) {
        $blocks += ConvertTo-ReleaseJson $release
    }
    return "[`n" + ($blocks -join ",`n") + "`n]`n"
}

# Set-Content -Encoding utf8 writes a BOM on 5.1. A BOM in a .json file breaks
# strict parsers and shows up as a spurious diff, so write it out by hand.
function Write-Utf8NoBom {
    param(
        [string] $Path,
        [string] $Text
    )
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $encoding)
}

# Compares "1.2.10" style versions numerically, the same way the Lua checker
# does: -1 = a older, 0 = equal, 1 = a newer.
function Compare-ResourceVersion {
    param([string] $A, [string] $B)

    $va = @([regex]::Matches($A, '\d+') | ForEach-Object { [int] $_.Value })
    $vb = @([regex]::Matches($B, '\d+') | ForEach-Object { [int] $_.Value })

    $max = [Math]::Max($va.Count, $vb.Count)
    for ($i = 0; $i -lt $max; $i++) {
        $x = 0
        $y = 0
        if ($i -lt $va.Count) { $x = $va[$i] }
        if ($i -lt $vb.Count) { $y = $vb[$i] }
        if ($x -ne $y) {
            if ($x -lt $y) { return -1 }
            return 1
        }
    }
    return 0
}

# Rewrites the `version '...'` line in an fxmanifest.lua, keeping whatever quote
# style that file already uses.
function Set-ManifestVersion {
    param(
        [string] $ManifestPath,
        [string] $Version
    )

    if (-not (Test-Path $ManifestPath)) {
        throw "fxmanifest.lua not found: $ManifestPath"
    }

    $text = [System.IO.File]::ReadAllText($ManifestPath)
    $pattern = "(?m)^(\s*version\s*)(['`"])([^'`"]*)(['`"])"

    $match = [regex]::Match($text, $pattern)
    if (-not $match.Success) {
        throw "no version line found in $ManifestPath"
    }

    $old = $match.Groups[3].Value
    $line = $match.Groups[1].Value + $match.Groups[2].Value + $Version + $match.Groups[4].Value
    $updated = $text.Remove($match.Index, $match.Length).Insert($match.Index, $line)

    Write-Utf8NoBom -Path $ManifestPath -Text $updated
    return $old
}
