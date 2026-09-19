#!/usr/bin/env pwsh
#
# fetch-names.ps1 — pull Marvel Champions set names from the community data repo
# and write them to plain-text lists, one name per line. (PowerShell port of
# fetch-names.sh; uses built-in web + JSON support, so no curl/python needed.)
#
# Source (single source of truth):
#   https://github.com/zzorba/marvelsdb-json-data  ->  sets.json
#
# sets.json lists every "card set" with a `card_set_type_code`. We map those to
# three divider lists:
#   heroes      <- card_set_type_code == "hero"     (playable heroes)
#   villains    <- card_set_type_code == "villain"  (villains, deduped: no I/II/III stages)
#   encounters  <- card_set_type_code == "modular"  (encounter set names, e.g. "Bomb Scare")
#
# Output: names/heroes.txt, names/villains.txt, names/encounters.txt
#   - one name per line
#   - duplicates removed
#   - sorted (case-insensitive)
#
# Usage:
#   ./fetch-names.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutDir    = Join-Path $ScriptDir 'names'
$SetsUrl   = 'https://raw.githubusercontent.com/zzorba/marvelsdb-json-data/master/sets.json'

# Map of output-file basename -> card_set_type_code in sets.json.
$Lists = [ordered]@{
    heroes     = 'hero'
    villains   = 'villain'
    encounters = 'modular'
}

# --- fetch -----------------------------------------------------------------
Write-Host 'Fetching sets.json ...'
try {
    $response = Invoke-WebRequest -Uri $SetsUrl -UseBasicParsing
    $sets = $response.Content | ConvertFrom-Json
}
catch {
    [Console]::Error.WriteLine("Error: failed to download or parse $SetsUrl")
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}

if (-not ($sets -is [System.Array]) -or $sets.Count -eq 0) {
    [Console]::Error.WriteLine('Error: downloaded sets.json is empty or not the expected format.')
    exit 1
}

if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

# --- extract each list -----------------------------------------------------
foreach ($entry in $Lists.GetEnumerator()) {
    $name     = $entry.Key
    $typeCode = $entry.Value
    $outFile  = Join-Path $OutDir "$name.txt"

    # Unique, non-empty names for this set type, sorted case-insensitively.
    $names = $sets |
        Where-Object { $_.card_set_type_code -eq $typeCode -and $_.name -and $_.name.Trim() } |
        ForEach-Object { $_.name.Trim() } |
        Sort-Object -Unique -Culture 'en-US'

    # Write one name per line with a trailing newline, UTF-8 without BOM.
    $text = ($names -join "`n") + "`n"
    [System.IO.File]::WriteAllText($outFile, $text, [System.Text.UTF8Encoding]::new($false))

    Write-Host ("  {0}: {1} names -> {2}" -f $name, $names.Count, $outFile)
}

Write-Host 'Done.'
