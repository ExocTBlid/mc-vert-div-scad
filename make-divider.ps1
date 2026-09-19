#!/usr/bin/env pwsh
#
# make-divider.ps1 — generate a divider STL for a given name. (PowerShell port
# of make-divider.sh; behaves identically.)
#
# Usage:
#   ./make-divider.ps1 "Jessica Jones"
#   ./make-divider.ps1 "Spider Man" spider-man-custom.stl   # optional explicit output
#
# The name is injected into divider.scad's `label` variable via OpenSCAD's -D
# flag (the .scad file itself is not modified); the text is always rendered in
# UPPERCASE regardless of how the name is typed. By default the output STL is
# written into the stl/ directory, named after the input: lowercased, with
# spaces and hyphens both replaced by '_'. Hyphens are kept in the card TEXT
# (they are only normalised away in the filename). An optional second argument
# overrides the output path (used verbatim, relative to the current directory).
#
# Automatic fit: before rendering, the label's natural width is measured (via a
# fast 2D SVG projection). If it would overflow the usable card width, the card
# is rendered with fit_to_width=true so the text is squeezed to fit; short names
# that already fit are left at their natural proportions.
#
# Requirements: openscad on PATH.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Label,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$Output
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScadFile  = Join-Path $ScriptDir 'divider.scad'
$OutDir    = Join-Path $ScriptDir 'stl'

# --- argument handling -----------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Label)) {
    [Console]::Error.WriteLine('Usage: make-divider.ps1 "Name To Print" [output.stl]')
    exit 1
}

# Text on the card is always uppercase.
$LabelUpper = $Label.ToUpper()

if (-not (Test-Path -LiteralPath $ScadFile)) {
    [Console]::Error.WriteLine("Error: cannot find divider.scad at $ScadFile")
    exit 1
}

$OpenScad = Get-Command openscad -ErrorAction SilentlyContinue
if (-not $OpenScad) {
    [Console]::Error.WriteLine('Error: openscad is not installed or not on PATH.')
    exit 1
}

# --- derive the output filename -------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $OutFile = $Output
}
else {
    # The filename uses '_' as its only separator so that '-' is free to appear
    # in the card text without affecting names. Steps: lowercase, turn each run
    # of whitespace or hyphens into a single '_', drop anything that isn't
    # alphanumeric or '_', collapse repeated '_', and trim leading/trailing '_'.
    $slug = $Label.ToLower()
    $slug = [regex]::Replace($slug, '[\s\-]+', '_')     # spaces/hyphens -> '_'
    $slug = [regex]::Replace($slug, '[^a-z0-9_]', '')   # drop other chars
    $slug = [regex]::Replace($slug, '_+', '_')          # collapse repeats
    $slug = $slug.Trim('_')                             # trim leading/trailing

    if ([string]::IsNullOrEmpty($slug)) {
        [Console]::Error.WriteLine("Error: name '$Label' produced an empty filename.")
        exit 1
    }
    if (-not (Test-Path -LiteralPath $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    }
    $OutFile = Join-Path $OutDir "$slug.stl"
}

# --- automatic fit ---------------------------------------------------------
# Pull `name = <number>;` / `name = "string";` values from divider.scad so this
# stays in sync with the model.
$scadText = Get-Content -LiteralPath $ScadFile -Raw

function Read-ScadNum([string]$name, [double]$default) {
    $m = [regex]::Match($scadText, "(?m)^\s*$name\s*=\s*([0-9]+(?:\.[0-9]+)?)")
    if ($m.Success) { return [double]$m.Groups[1].Value } else { return $default }
}
function Read-ScadStr([string]$name, [string]$default) {
    $m = [regex]::Match($scadText, "(?m)^\s*$name\s*=\s*""([^""]*)""")
    if ($m.Success) { return $m.Groups[1].Value } else { return $default }
}

$cardW          = Read-ScadNum 'card_w' 75
$textSideMargin = Read-ScadNum 'text_side_margin' 4
$textSize       = Read-ScadNum 'text_size' 8
$scadFont       = Read-ScadStr 'font' 'BentonSans ExtraComp Black:style=Regular'

$usableW = $cardW - 2 * $textSideMargin

# Measure the label's natural rendered width with a quick 2D SVG projection.
$fitFlag     = @()
$measureScad = [System.IO.Path]::GetTempFileName() + '.scad'
$measureSvg  = [System.IO.Path]::GetTempFileName() + '.svg'

try {
    # Escape any double quotes in the label for embedding in the .scad snippet.
    $labelEscaped = $LabelUpper -replace '"', '\"'
    $snippet = 'text("{0}", size={1}, font="{2}", halign="center", valign="top");' -f `
        $labelEscaped, $textSize, $scadFont
    Set-Content -LiteralPath $measureScad -Value $snippet -Encoding UTF8

    $textW = $null
    & openscad -o $measureSvg $measureScad 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $measureSvg)) {
        $svg = Get-Content -LiteralPath $measureSvg -Raw
        if (-not [string]::IsNullOrEmpty($svg)) {
            $m = [regex]::Match($svg, 'width="([0-9.]+)mm"')
            if ($m.Success) { $textW = [double]$m.Groups[1].Value }
        }
    }

    if ($null -ne $textW) {
        if ($textW -gt $usableW) {
            Write-Host ("  (label {0}mm > usable {1}mm - fitting to width)" -f $textW, $usableW)
            $fitFlag = @('-D', 'fit_to_width=true')
        }
    }
    else {
        Write-Warning '  (could not measure text width; rendering at natural size)'
    }
}
finally {
    Remove-Item -LiteralPath $measureScad, $measureSvg -ErrorAction SilentlyContinue
}

# --- render ----------------------------------------------------------------
Write-Host "Generating '$LabelUpper' -> $OutFile"
& openscad -o $OutFile -D "label=`"$LabelUpper`"" @fitFlag $ScadFile
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("openscad failed (exit $LASTEXITCODE).")
    exit $LASTEXITCODE
}

Write-Host "Done: $OutFile"
