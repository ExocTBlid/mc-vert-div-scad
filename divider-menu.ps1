#!/usr/bin/env pwsh
#
# divider-menu.ps1 — interactive / piped front-end for make-divider.ps1.
# (PowerShell port of divider-menu.sh; behaves identically.)
#
# Two modes:
#
# Interactive (run in a terminal) — a menu lets you either:
#   1) Choose from a list  — pick one of the names/*.txt files (heroes,
#      villains, encounters, ...), then select one, several, or all entries.
#   2) Enter manually      — type any name(s) yourself.
#
# Piped / non-interactive (stdin is redirected) — reads names from stdin, one
# per line, and generates a divider for each. Blank lines and lines that start
# with '#' are ignored, so you can pipe a custom list:
#   Get-Content my-list.txt | ./divider-menu.ps1
#   "Thor","Loki" | ./divider-menu.ps1
#   ./divider-menu.ps1 < names\heroes.txt
#
# Selection syntax when choosing from a list (interactive mode):
#   1 3 5        individual items (space or comma separated)
#   2-6          an inclusive range
#   1 4-6 9      any mix of the above
#   all          every item in the list
#
# Requirements: make-divider.ps1 (same directory), the names/ lists (optional;
# generate them with fetch-names.ps1), openscad.

[CmdletBinding()]
param(
    # Names piped in via the pipeline are bound here (one element per line).
    [Parameter(ValueFromPipeline = $true)]
    [string[]]$InputName
)

begin {
    $ErrorActionPreference = 'Stop'

    $ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
    $MakeDivider = Join-Path $ScriptDir 'make-divider.ps1'
    $NamesDir    = Join-Path $ScriptDir 'names'

    if (-not (Test-Path -LiteralPath $MakeDivider)) {
        [Console]::Error.WriteLine("Error: cannot find make-divider.ps1 at $MakeDivider")
        exit 1
    }

    # Generate a divider for a single name, printing a small header first.
    function Invoke-One([string]$name) {
        Write-Host "`n--- $name ---"
        & $MakeDivider $name
    }

    # Parse a selection string ("1 3 5", "2-6", "all") against a count of items.
    # Returns the chosen 1-based indices, de-duplicated and in order, or $null
    # if the selection is empty/invalid.
    function Get-Selection([string]$sel, [int]$count) {
        $sel = $sel -replace ',', ' '
        $chosen = [System.Collections.Generic.List[int]]::new()

        if (($sel -replace '\s', '').ToLower() -eq 'all') {
            1..$count | ForEach-Object { $chosen.Add($_) }
        }
        else {
            foreach ($token in ($sel -split '\s+' | Where-Object { $_ -ne '' })) {
                if ($token -match '^([0-9]+)-([0-9]+)$') {
                    $lo = [int]$Matches[1]; $hi = [int]$Matches[2]
                    if ($lo -lt 1 -or $hi -lt 1 -or $lo -gt $count -or $hi -gt $count -or $lo -gt $hi) {
                        Write-Host "  ! range out of bounds: $token"
                        return $null
                    }
                    $lo..$hi | ForEach-Object { $chosen.Add($_) }
                }
                elseif ($token -match '^[0-9]+$') {
                    $n = [int]$token
                    if ($n -lt 1 -or $n -gt $count) {
                        Write-Host "  ! out of range: $token"
                        return $null
                    }
                    $chosen.Add($n)
                }
                else {
                    Write-Host "  ! not a number or range: $token"
                    return $null
                }
            }
        }

        if ($chosen.Count -eq 0) { return $null }

        # De-duplicate while preserving order.
        $seen = [System.Collections.Generic.HashSet[int]]::new()
        $result = [System.Collections.Generic.List[int]]::new()
        foreach ($idx in $chosen) {
            if ($seen.Add($idx)) { $result.Add($idx) }
        }
        return $result.ToArray()
    }

    # --- interactive: manual entry -----------------------------------------
    function Invoke-Manual {
        while ($true) {
            $name = (Read-Host "`nEnter a name (blank to finish)").Trim()
            if ([string]::IsNullOrEmpty($name)) { break }
            Invoke-One $name
        }
    }

    # --- interactive: choose from a list -----------------------------------
    function Invoke-FromList {
        $files = @()
        if (Test-Path -LiteralPath $NamesDir) {
            $files = Get-ChildItem -LiteralPath $NamesDir -Filter '*.txt' -File |
                Sort-Object Name
        }

        if ($files.Count -eq 0) {
            Write-Host "No name lists found in $NamesDir."
            Write-Host 'Run ./fetch-names.ps1 first to generate them.'
            return
        }

        Write-Host "`nAvailable lists:"
        for ($i = 0; $i -lt $files.Count; $i++) {
            $base  = [System.IO.Path]::GetFileNameWithoutExtension($files[$i].Name)
            $count = (Get-Content -LiteralPath $files[$i].FullName |
                Where-Object { $_ -ne '' }).Count
            '{0,4}) {1,-14} ({2} names)' -f ($i + 1), $base, $count | Write-Host
        }

        $pick = Read-Host 'Choose a list number'
        if ($pick -notmatch '^[0-9]+$' -or [int]$pick -lt 1 -or [int]$pick -gt $files.Count) {
            Write-Host 'Invalid list choice.'
            return
        }
        $listFile = $files[[int]$pick - 1]

        $names = @(Get-Content -LiteralPath $listFile.FullName |
            Where-Object { $_.Trim() -ne '' })

        if ($names.Count -eq 0) {
            Write-Host "List '$($listFile.Name)' is empty."
            return
        }

        Write-Host "`n$([System.IO.Path]::GetFileNameWithoutExtension($listFile.Name)):"
        for ($i = 0; $i -lt $names.Count; $i++) {
            '{0,5}) {1}' -f ($i + 1), $names[$i] | Write-Host
        }

        Write-Host "`nSelect items: numbers/ranges (e.g. '1 3 5' or '2-6'), or 'all'."
        $sel = Read-Host 'Selection'

        $indices = Get-Selection $sel $names.Count
        if ($null -eq $indices -or $indices.Count -eq 0) {
            Write-Host 'No valid selection made.'
            return
        }

        Write-Host "`nGenerating $($indices.Count) divider(s)..."
        foreach ($idx in $indices) {
            Invoke-One $names[$idx - 1]
        }
    }

    # --- interactive main menu ---------------------------------------------
    function Invoke-Menu {
        Write-Host '=============================='
        Write-Host ' Marvel Champions Divider Menu'
        Write-Host '=============================='
        Write-Host ''
        Write-Host 'How do you want to pick names?'
        Write-Host '  1) Choose from a list'
        Write-Host '  2) Enter manually'
        Write-Host '  q) Quit'

        $choice = Read-Host 'Choice'
        switch ($choice) {
            '1'     { Invoke-FromList }
            '2'     { Invoke-Manual }
            { $_ -in 'q', 'Q' } { Write-Host 'Bye.'; return }
            default { Write-Host "Unrecognised choice: '$choice'"; return }
        }

        Write-Host "`nAll done."
    }

    # Detect piped input. When stdin is redirected the pipeline binds lines to
    # $InputName in the process block below; otherwise we run the menu in end{}.
    $script:PipedCount = 0
    $script:SawPipelineInput = $false
    $script:IsPiped = [Console]::IsInputRedirected
}

process {
    # Only runs when names are piped in.
    if ($null -ne $InputName) {
        $script:SawPipelineInput = $true
        foreach ($line in $InputName) {
            $name = $line.Trim()
            if ([string]::IsNullOrEmpty($name)) { continue }
            if ($name.StartsWith('#')) { continue }
            Invoke-One $name
            $script:PipedCount++
        }
    }
}

end {
    # Treat as piped if stdin was redirected OR the pipeline actually delivered
    # names (covers `x,y | script` where IsInputRedirected can be false).
    $piped = $script:IsPiped -or $script:SawPipelineInput
    if ($piped) {
        if ($script:PipedCount -eq 0) {
            Write-Host 'No names read from stdin.'
            exit 1
        }
        Write-Host "`nGenerated $($script:PipedCount) divider(s) from stdin."
    }
    else {
        Invoke-Menu
    }
}
