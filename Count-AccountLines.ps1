<#
.SYNOPSIS
    Counts description lines per account and identifies possible bill overprints.
.DESCRIPTION
    Terminal workspace with keyboard menus, CSV browsing, account search,
    CSV preview, a destination folder explorer, and a bottom progress panel.
    Blank AccountNumber cells continue the preceding account. Every nonblank
    explicit Description line counts, including ACCOUNT TOTAL and NOT USED.
    Possible overprint means 8 or more lines. Printed wrapping is not measured.
.AUTHOR
    Teo Espero
    Marina Coast Water District
    Developed with assistance from OpenAI ChatGPT.
.NOTES
    Filename: Count-AccountLines.ps1
    Version: 1.14
    Last updated: 2026-10-16
    Target: Windows PowerShell 5.1 / PowerShell 7 in a console terminal.
    Encoding: UTF-8 with BOM for Windows PowerShell Unicode compatibility.

    REVISION HISTORY
    All revisions below were prepared on 2026-10-16.
    1.00  Initial line counting and CSV summary report.
    1.01  Added input browsing and dated output filename convention.
    1.02  Added a graphical workspace prototype.
    1.03  Replaced the graphical workspace with a terminal interface.
    1.04  Added progress reporting and exact CSV preview.
    1.05  Added full/partial account search and description previews.
    1.06  Added boxed terminal layout.
    1.07  Added help and automatic processing after CSV selection.
    1.08  Added highlighted keyboard menus and file explorer navigation.
    1.09  Reduced menu flicker and added destination folder browsing.
    1.10  Added Unicode box borders and selection background colors.
    1.11  Replaced standard progress with a custom bottom progress panel.
    1.12  Unified padding/widths; added authorship and inline documentation.
    1.13  Fixed progress cursor restoration, synchronous output, and box closure.
    1.14  Moved activity, completion, save, and error status to the bottom panel.
.EXAMPLE
    .\Count-AccountLines.ps1
    Opens the workspace. Use arrow keys and Enter to choose menu options.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
# Session state: original input path, account results, detail lines, and status.
$script:InputPath = $null
$script:Results = @()
$script:Descriptions = @{}
$script:Log = 'Start with 1: choose a CSV. It will be processed automatically.'

# One shared content width: border + one space + content + one space + border.
# Reserve one unused terminal column to prevent automatic line wrapping.
function Get-PanelWidth {
    $columns = 100
    try { $columns = $Host.UI.RawUI.WindowSize.Width } catch { }
    return [Math]::Max(1,[Math]::Min(110,$columns-5))
}
# Unicode box borders and full-row menu selection. UTF-8 BOM supports Windows PowerShell 5.1.
function Write-PanelLine {
    param(
        [Parameter(Position=0)][AllowEmptyString()][object]$Object = '',
        [System.ConsoleColor]$ForegroundColor = [System.ConsoleColor]::Gray,
        [System.ConsoleColor]$BackgroundColor = [System.ConsoleColor]::Black
    )
    $width = Get-PanelWidth
    $value = [string]$Object
    foreach ($line in ($value -split "`r?`n")) {
        if ($line.Length -eq 0) {
            Microsoft.PowerShell.Utility\Write-Host ('│ ' + (' ' * $width) + ' │') -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
            continue
        }
        for ($offset=0; $offset -lt $line.Length; $offset += $width) {
            $part = $line.Substring($offset, [Math]::Min($width,$line.Length-$offset))
            Microsoft.PowerShell.Utility\Write-Host ('│ ' + $part.PadRight($width) + ' │') -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
        }
    }
}
function Write-PanelBorder {
    param([ValidateSet('Top','Middle','Bottom')][string]$Kind = 'Middle')
    $width = Get-PanelWidth
    $edges = switch ($Kind) { 'Top' { @('┌','┐') }; 'Bottom' { @('└','┘') }; default { @('├','┤') } }
    Microsoft.PowerShell.Utility\Write-Host ($edges[0] + ('─' * ($width+2)) + $edges[1]) -ForegroundColor DarkCyan -BackgroundColor Black
}
function Read-PathText([string]$Prompt) {
    Write-PanelBorder -Kind Bottom
    return (Read-Host $Prompt).Trim().Trim('"')
}
function Show-Header([string]$Title) {
    Clear-Host
    Write-PanelBorder -Kind Top
    Write-PanelLine 'MCWD  /  ACCOUNT LINES COUNT' -ForegroundColor Cyan
    Write-PanelBorder
    Write-PanelLine $Title -ForegroundColor Yellow
    Write-PanelBorder
    Show-BottomProgress -Message $script:Log -StatusOnly
}
# Keyboard menus use real console key events; no mouse or graphical dialogs.
# Repaint at a stable cursor location; keep selection visible using paged rows.
# Return a zero-based option index, or -1 when the user presses Escape.
function Select-TerminalMenu {
    param([string]$Title, [string[]]$Options, [string[]]$Context = @())
    $index = 0
    $pageSize = 8
    try { $pageSize = [Math]::Max(2,[Math]::Min(10,$Host.UI.RawUI.WindowSize.Height - 21 - $Context.Count)) } catch { }
    Clear-Host
    $origin = $Host.UI.RawUI.CursorPosition
    $oldCursor = $true
    try { $oldCursor = [Console]::CursorVisible; [Console]::CursorVisible = $false } catch { }
    try {
    while ($true) {
        # Repaint at the same origin: no Clear-Host flash on each arrow key.
        $Host.UI.RawUI.CursorPosition = $origin
        Write-PanelBorder -Kind Top
        Write-PanelLine 'MCWD / ACCOUNT LINES COUNT' -ForegroundColor Cyan
        Write-PanelBorder
        Write-PanelLine $Title -ForegroundColor Yellow
        Write-PanelBorder
        foreach ($line in $Context) { Write-PanelLine $line -ForegroundColor Cyan }
        Write-PanelLine 'UP/DOWN: move | ENTER: select | ESC: back | HOME/END: first/last' -ForegroundColor DarkGray
        Write-PanelBorder
        $start = [int]([Math]::Floor($index / [double]$pageSize) * $pageSize)
        $end = [Math]::Min($start+$pageSize,$Options.Count)
        for ($i=$start; $i -lt $end; $i++) {
            $label = $Options[$i]
            $available = [Math]::Max(1,(Get-PanelWidth)-4)
            if ($label.Length -gt $available) { $label = $label.Substring(0,[Math]::Max(0,$available-1)) + '…' }
            if ($i -eq $index) {
                Write-PanelLine ('▶   ' + $label) -ForegroundColor White -BackgroundColor DarkBlue
            } else {
                Write-PanelLine ('    ' + $label)
            }
        }
        for ($blank=$end-$start; $blank -lt $pageSize; $blank++) { Write-PanelLine '' }
        Write-PanelBorder
        Write-PanelLine "Option $($index+1) of $($Options.Count)" -ForegroundColor DarkGray
        Write-PanelBorder -Kind Bottom
        Show-BottomProgress -Message $script:Log -StatusOnly
        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        switch ($key.VirtualKeyCode) {
            38 { if ($index -gt 0) { $index-- } }
            40 { if ($index -lt $Options.Count-1) { $index++ } }
            36 { $index=0 }
            35 { $index=$Options.Count-1 }
            33 { $index=[Math]::Max(0,$index-$pageSize) }
            34 { $index=[Math]::Min($Options.Count-1,$index+$pageSize) }
            13 { return $index }
            27 { return -1 }
        }
    }
    } finally {
        try { [Console]::CursorVisible = $oldCursor } catch { }
    }
}
# Browse only folders and CSV files. Returns the selected absolute file path.
function Select-Csv {
    $folder = (Get-Location).Path
    while ($true) {
        try {
            $items = @(Get-ChildItem -LiteralPath $folder -ErrorAction Stop |
                Where-Object { $_.PSIsContainer -or $_.Extension -ieq '.csv' } |
                Sort-Object @{Expression={ -not $_.PSIsContainer }}, Name)
        } catch {
            Write-PanelLine "Cannot list folder: $($_.Exception.Message)" -ForegroundColor Red
            [void](Read-Host 'Press Enter')
            $items=@()
        }
        $options = @('.. Parent folder','Paste a folder or CSV path','Cancel')
        foreach ($item in $items) {
            $kind = if ($item.PSIsContainer) { '[DIR]' } else { '[CSV]' }
            $options += "$kind $($item.Name)"
        }
        $choice = Select-TerminalMenu -Title 'EXPLORER | Select a CSV file' -Options $options -Context @("Folder: $folder")
        if ($choice -eq -1 -or $choice -eq 2) { return $null }
        if ($choice -eq 0) {
            $parent = Split-Path -Path $folder -Parent
            if ($parent) { $folder = $parent }
            continue
        }
        if ($choice -eq 1) {
            $candidate = Read-PathText 'Paste folder or CSV path (Enter cancels)'
            if (-not $candidate) { continue }
            try {
                $item = Get-Item -LiteralPath $candidate -ErrorAction Stop
                if ($item.PSIsContainer) { $folder=$item.FullName }
                elseif ($item.Extension -ieq '.csv') { return $item.FullName }
                else { throw 'Please choose a CSV file.' }
            } catch {
                Write-PanelLine $_.Exception.Message -ForegroundColor Red
                [void](Read-Host 'Press Enter to return to the file browser')
            }
            continue
        }
        $item = $items[$choice-3]
        if ($item.PSIsContainer) { $folder=$item.FullName }
        else { return $item.FullName }
    }
}
# Paint progress in the bottom three visible terminal rows, preserving the cursor.
function Show-BottomProgress {
    param([int]$Current, [int]$Total, [switch]$Clear, [string]$Message = '', [switch]$StatusOnly)
    # Copy scalar coordinates; never alias mutable RawUI Coordinates objects.
    # Console.Write keeps cursor positioning and output synchronous in Windows Terminal.
    $savedX = [Console]::CursorLeft
    $savedY = [Console]::CursorTop
    $savedForeground = [Console]::ForegroundColor
    $savedBackground = [Console]::BackgroundColor
    try {
        $width = Get-PanelWidth
        $left = [Console]::WindowLeft
        $top = [Console]::WindowTop + [Console]::WindowHeight - 5
        if ($top -lt 0) { return }
        $percent = if ($Total -gt 0) { [Math]::Min(100,[int](100.0*$Current/$Total)) } else { 0 }
        $barWidth = [Math]::Max(1,[Math]::Min(40,$width-9))
        $filled = [int][Math]::Floor($barWidth*$percent/100.0)
        $bar = ('█' * $filled) + ('░' * ($barWidth-$filled))
        $status = if ($Message) { $Message } else { "Processing $Current / $Total records" }
        $barText = if ($StatusOnly) { 'STATUS / ACTIVITY' } else { "[$bar] $percent%" }
        $lines = @(
            ('┌' + ('─' * ($width+2)) + '┐'),
            ('│ ' + $barText.Substring(0,[Math]::Min($barText.Length,$width)).PadRight($width) + ' │'),
            ('│ ' + $status.Substring(0,[Math]::Min($status.Length,$width)).PadRight($width) + ' │'),
            ('└' + ('─' * ($width+2)) + '┘')
        )
        [Console]::ForegroundColor = [ConsoleColor]::Cyan
        [Console]::BackgroundColor = [ConsoleColor]::Black
        for ($i=0; $i -lt 4; $i++) {
            [Console]::SetCursorPosition($left,$top+$i)
            $text = if ($Clear) { ' ' * ($width+4) } else { $lines[$i] }
            [Console]::Write($text)
        }
    } finally {
        [Console]::ForegroundColor = $savedForeground
        [Console]::BackgroundColor = $savedBackground
        [Console]::SetCursorPosition($savedX,$savedY)
    }
}
# Shared status setter keeps messages out of the main workspace.
function Set-ActivityStatus([string]$Message) {
    $script:Log = $Message
    Show-BottomProgress -Message $Message -StatusOnly
}
function Invoke-Count {
    if (-not $script:InputPath) { throw 'Browse for an input CSV first.' }
    $script:Results = @()
    Show-Header 'PROCESSING | Counting account description lines'
    Write-PanelLine ('Input: ' + $script:InputPath)
    Write-PanelBorder -Kind Bottom
    Set-ActivityStatus 'Loading the selected CSV...'
    $rows = @(Import-Csv -LiteralPath $script:InputPath)
    if ($rows.Count -eq 0) { throw 'The CSV has no data rows.' }
    foreach ($column in @('AccountNumber','Description')) {
        if ($column -notin $rows[0].PSObject.Properties.Name) { throw "Missing required column: $column" }
    }
    $counts = [ordered]@{}
    $script:Descriptions = @{}
    $account = $null
    $rowIndex = 0
    # Update about 100 times per run to avoid excessive terminal repainting.
    $progressStep = [Math]::Max(1, [int]($rows.Count / 100))
    foreach ($row in $rows) {
        $rowIndex++
        if ($rowIndex -eq 1 -or $rowIndex % $progressStep -eq 0 -or $rowIndex -eq $rows.Count) {
            Show-BottomProgress -Current $rowIndex -Total $rows.Count
        }
        $nextAccount = ([string]$row.AccountNumber).Trim()
        # Carry the account forward across blank AccountNumber cells.
        if ($nextAccount) {
            $account = $nextAccount
            if (-not $counts.Contains($account)) {
                $counts[$account] = 0
                $script:Descriptions[$account] = New-Object 'System.Collections.Generic.List[string]'
            }
        }
        if ([string]::IsNullOrWhiteSpace([string]$row.Description)) { continue }
        if (-not $account) { throw 'A description appears before the first account number.' }
        # Count explicit nonblank lines, including ACCOUNT TOTAL and NOT USED.
        foreach ($line in ([string]$row.Description -split '\r\n|\n|\r')) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $counts[$account]++
                $script:Descriptions[$account].Add($line)
            }
        }
    }
    $script:Results = @(
        foreach ($key in $counts.Keys) {
            [PSCustomObject]@{ 'Account #' = $key; Lines = [int]$counts[$key] }
        }
    )
    Show-BottomProgress -Current $rows.Count -Total $rows.Count
    $script:Log = "Complete: $($rows.Count) records; $($script:Results.Count) accounts."
    Show-BottomProgress -Current $rows.Count -Total $rows.Count -Message $script:Log
    [void](Read-Host 'Press Enter to view the menu')
}
# Page through counts; optional overprint filtering changes only the view.
function Show-Results {
    if ($script:Results.Count -eq 0) { throw 'Process a CSV first.' }
    Write-PanelLine 'Press Enter to show all accounts, or Y to show only possible overprints.'
    $onlyOverprint = (Read-Host 'Overprints only? [Enter = No]').Trim() -ieq 'Y'
    $view = @($script:Results | Where-Object { -not $onlyOverprint -or $_.Lines -ge 8 })
    $page = 0
    $pageSize = 20
    $pages = [Math]::Max(1,[int][Math]::Ceiling($view.Count / [double]$pageSize))
    while ($true) {
        Show-Header "RESULTS | Page $($page+1) of $pages | $($view.Count) accounts"
        Write-PanelLine (' {0,-28} {1,8}  {2}' -f 'Account #','Lines','Status') -ForegroundColor Cyan
        foreach ($item in @($view | Select-Object -Skip ($page*$pageSize) -First $pageSize)) {
            $flag = if ($item.Lines -ge 8) { 'Possible overprint' } else { '' }
            $color = if ($item.Lines -ge 8) { 'Yellow' } else { 'Gray' }
            Write-PanelLine (' {0,-28} {1,8}  {2}' -f $item.'Account #',$item.Lines,$flag) -ForegroundColor $color
        }
        Write-PanelLine ''
        Write-PanelBorder
        $choice = (Read-Host 'N = next | P = previous | Q = return').Trim().ToUpperInvariant()
        if ($choice -eq 'Q') { return }
        if ($choice -eq 'N' -and $page -lt $pages-1) { $page++ }
        if ($choice -eq 'P' -and $page -gt 0) { $page-- }
    }
}
# Search literal account text, then show the source description lines that
# contributed to the selected account count. Exact matches open directly.
function Show-AccountPreview {
    if ($script:Results.Count -eq 0) { throw 'Process a CSV first.' }
    while ($true) {
        Show-Header 'ACCOUNT SEARCH | Full or partial account number'
        Write-PanelLine 'Leading zeros are preserved. Enter Q to return.'
        Write-PanelBorder
        $query = (Read-Host 'Account number or partial number').Trim()
        if ($query -ieq 'Q') { return }
        if (-not $query) { continue }
        # Prefer an exact match; otherwise use a literal substring search.
        $matches = @($script:Results | Where-Object { $_.'Account #' -eq $query })
        if ($matches.Count -eq 0) {
            $matches = @($script:Results | Where-Object { $_.'Account #'.IndexOf($query, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 })
        }
        if ($matches.Count -eq 0) {
            Write-PanelLine 'No matching accounts.' -ForegroundColor Yellow
            [void](Read-Host 'Press Enter to search again')
            continue
        }
        $page = 0
        $pageSize = 15
        $pages = [int][Math]::Ceiling($matches.Count / [double]$pageSize)
        $selected = if ($matches.Count -eq 1) { $matches[0] } else { $null }
        while (-not $selected) {
            Show-Header "ACCOUNT SEARCH | $($matches.Count) matches | Page $($page+1) of $pages"
            $end = [Math]::Min(($page+1)*$pageSize,$matches.Count)
            for ($i=$page*$pageSize; $i -lt $end; $i++) {
                Write-PanelLine (' {0,4}  {1,-20} {2,4} lines' -f ($i+1),$matches[$i].'Account #',$matches[$i].Lines)
            }
            Write-PanelBorder
        $choice = (Read-Host 'Select number | N next | P previous | Q new search').Trim()
            if ($choice -ieq 'Q') { break }
            if ($choice -ieq 'N') { if ($page -lt $pages-1) { $page++ }; continue }
            if ($choice -ieq 'P') { if ($page -gt 0) { $page-- }; continue }
            $number = 0
            if ([int]::TryParse($choice,[ref]$number) -and $number -ge 1 -and $number -le $matches.Count) {
                $selected = $matches[$number-1]
            }
        }
        if (-not $selected) { continue }
        $lines = $script:Descriptions[$selected.'Account #']
        $page = 0
        $pages = [Math]::Max(1,[int][Math]::Ceiling($lines.Count / 15.0))
        while ($true) {
            Show-Header "ACCOUNT $($selected.'Account #') | Description preview | Page $($page+1) of $pages"
            $flag = if ($selected.Lines -ge 8) { 'YES' } else { 'NO' }
            Write-PanelLine " Lines: $($selected.Lines) | Possible overprint (>= 8): $flag" -ForegroundColor Cyan
            Write-PanelLine ''
            $end = [Math]::Min(($page+1)*15,$lines.Count)
            for ($i=$page*15; $i -lt $end; $i++) {
                Write-PanelLine (' {0,4} | {1}' -f ($i+1),$lines[$i])
            }
            Write-PanelLine ''
            Write-PanelLine 'CSV detail row:' -ForegroundColor DarkGray
            Write-PanelLine (($selected | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1) -join "`n") -ForegroundColor Cyan
            Write-PanelBorder
        $choice = (Read-Host 'N next | P previous | Q new search').Trim()
            if ($choice -ieq 'Q') { break }
            if ($choice -ieq 'N' -and $page -lt $pages-1) { $page++ }
            if ($choice -ieq 'P' -and $page -gt 0) { $page-- }
        }
    }
}
# Preview and saving share this function so their CSV content stays identical.
function Get-ReportCsv {
    $overprints = @($script:Results | Where-Object { $_.Lines -ge 8 }).Count
    $report = @(
        [PSCustomObject][ordered]@{ 'Account #' = 'Number of accounts:'; Lines = $script:Results.Count }
        [PSCustomObject][ordered]@{ 'Account #' = 'Number of accounts with possible overprint:'; Lines = $overprints }
        [PSCustomObject][ordered]@{ 'Account #' = ''; Lines = '' }
        [PSCustomObject][ordered]@{ 'Account #' = 'Account #'; Lines = 'Lines' }
    ) + $script:Results
    $report | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1
}
# Display the exact export lines with on-screen row numbers. Those row numbers
# are for navigation only and are not included in the saved CSV.
function Show-CsvPreview {
    if ($script:Results.Count -eq 0) { throw 'Process a CSV first.' }
    $csvLines = @(Get-ReportCsv)
    $pageSize = 20
    $page = 0
    $pages = [int][Math]::Ceiling($csvLines.Count / [double]$pageSize)
    while ($true) {
        Show-Header "CSV PREVIEW | Page $($page+1) of $pages | $($csvLines.Count) CSV rows"
        Write-PanelLine 'Exact output content, including summary and account detail.' -ForegroundColor DarkGray
        Write-PanelLine ''
        $end = [Math]::Min(($page+1)*$pageSize, $csvLines.Count)
        for ($i = $page*$pageSize; $i -lt $end; $i++) {
            Write-PanelLine (' {0,5} | {1}' -f ($i+1),$csvLines[$i]) -ForegroundColor Cyan
        }
        Write-PanelLine ''
        Write-PanelBorder
        $choice = (Read-Host 'N = next | P = previous | F = first | L = last | Q = return').Trim().ToUpperInvariant()
        switch ($choice) {
            'N' { if ($page -lt $pages-1) { $page++ } }
            'P' { if ($page -gt 0) { $page-- } }
            'F' { $page = 0 }
            'L' { $page = $pages-1 }
            'Q' { return }
        }
    }
}
# Destination explorer returns a folder; cancellation never writes a report.
function Select-SaveFolder([string]$InitialFolder) {
    $folder = $InitialFolder
    while ($true) {
        try {
            $directories = @(Get-ChildItem -LiteralPath $folder -Directory -ErrorAction Stop | Sort-Object Name)
        } catch {
            Write-PanelLine "Cannot open folder: $($_.Exception.Message)" -ForegroundColor Red
            [void](Read-Host 'Press Enter')
            $directories = @()
        }
        $options = @('SAVE IN THIS FOLDER','.. Parent folder','Choose a drive','Paste a folder path','Cancel')
        foreach ($directory in $directories) { $options += '[DIR] ' + $directory.Name }
        $choice = Select-TerminalMenu -Title 'SAVE EXPLORER | Choose destination folder' -Options $options -Context @("Folder: $folder")
        if ($choice -eq -1 -or $choice -eq 4) { return $null }
        if ($choice -eq 0) { return $folder }
        if ($choice -eq 1) {
            $parent = Split-Path -Path $folder -Parent
            if ($parent) { $folder = $parent }
            continue
        }
        if ($choice -eq 2) {
            $drives = @(Get-PSDrive -PSProvider FileSystem | Where-Object { Test-Path -LiteralPath $_.Root })
            if ($drives.Count -gt 0) {
                $driveIndex = Select-TerminalMenu -Title 'SAVE EXPLORER | Drives' -Options @($drives | ForEach-Object { $_.Root })
                if ($driveIndex -ge 0) { $folder = $drives[$driveIndex].Root }
            }
            continue
        }
        if ($choice -eq 3) {
            $candidate = Read-PathText 'Paste destination folder (Enter cancels)'
            if ($candidate) {
                if (Test-Path -LiteralPath $candidate -PathType Container) {
                    $folder = (Get-Item -LiteralPath $candidate).FullName
                } else {
                    Write-PanelLine 'That folder does not exist or cannot be accessed.' -ForegroundColor Red
                    [void](Read-Host 'Press Enter')
                }
            }
            continue
        }
        $folder = $directories[$choice-5].FullName
    }
}
# Export all processed accounts, independent of preview filters. Protect the
# source file and prompt before replacing an existing destination report.
function Save-Report {
    if ($script:Results.Count -eq 0) { throw 'Process a CSV first.' }
    Set-ActivityStatus 'Choose a folder for the CSV report.'
    $folder = Select-SaveFolder ([System.IO.Path]::GetDirectoryName($script:InputPath))
    if (-not $folder) { Set-ActivityStatus 'Save cancelled.'; return }
    $prefix = ([System.IO.Path]::GetFileNameWithoutExtension($script:InputPath) -split '-',2)[0]
    # Requested date order: YYYYDDMM.
    $fileName = "$prefix-Account Lines Count-TE-$(Get-Date -Format 'yyyyddMM').csv"
    $output = [System.IO.Path]::GetFullPath((Join-Path $folder $fileName))
    if ($output -eq $script:InputPath) { throw 'The source CSV cannot be overwritten.' }
    if (Test-Path -LiteralPath $output) {
        if ((Read-Host "File exists: $output. Overwrite? (Y/N)").Trim() -ine 'Y') {
            Set-ActivityStatus 'Save cancelled.'
            return
        }
    }
    Set-ActivityStatus 'Saving the CSV report...'
    Get-ReportCsv | Set-Content -LiteralPath $output -Encoding UTF8
    Set-ActivityStatus "Saved: $output"
}
# Main event loop: keep the terminal open after actions and recover from errors.
while ($true) {
    $inputLabel = if ($script:InputPath) { $script:InputPath } else { '(none selected)' }
    $overprints = @($script:Results | Where-Object { $_.Lines -ge 8 }).Count
    $menuOptions = @(
        'Browse for a CSV and process it',
        'Reprocess selected CSV',
        'View account counts / possible overprints',
        'Save CSV report',
        'Preview resulting CSV',
        'Search / preview specific accounts',
        'Help: how the counts work',
        'Quit'
    )
    $context = @(
        "Input: $inputLabel",
        "Accounts: $($script:Results.Count) | Possible overprint (>= 8): $overprints"
    )
    $selectedIndex = Select-TerminalMenu -Title 'WORKSPACE | Description line counter' -Options $menuOptions -Context $context
    if ($selectedIndex -eq -1) { continue }
    $choice = @('1','2','3','4','5','6','H','Q')[$selectedIndex]
    try {
        switch ($choice) {
            '1' {
                $selected = Select-Csv
                if ($selected) {
                    $script:InputPath = $selected
                    $script:Results = @()
                    Invoke-Count
                }
            }
            '2' { Invoke-Count }
            '3' { Show-Results }
            '4' { Save-Report }
            '5' { Show-CsvPreview }
            '6' { Show-AccountPreview }
            'H' {
                Show-Header 'HELP | A quick guide'
                Write-PanelLine '1. Browse: use arrow keys and Enter. Choose Paste path to enter a location.'
                Write-PanelLine '2. The CSV is processed automatically after selection.'
                Write-PanelLine '3. View results, preview the CSV, or search for an account.'
                Write-PanelLine '4. Save exports all accounts and the summary, regardless of your current view.'
                Write-PanelLine ''
                Write-PanelLine 'Required columns: AccountNumber and Description.'
                Write-PanelLine 'Blank account cells continue the previous account. Leading zeros are kept.'
                Write-PanelLine 'Every nonblank description line counts, including ACCOUNT TOTAL and NOT USED.'
                Write-PanelLine '8 or more lines means possible overprint. Printed wrapping is not measured.'
                Write-PanelLine 'XX is the source filename prefix. The date is year + day + month.'
                Write-PanelLine 'Search accepts full or partial account numbers. Exact matches open directly.'
                Write-PanelBorder
                [void](Read-Host 'Press Enter to return to the main menu')
            }
            'Q' { return }
            default { $script:Log = 'Choose 1-6, H for help, or Q to quit.' }
        }
    } catch {
        try { Show-BottomProgress -Clear } catch { }
        $script:Log = "ERROR: $($_.Exception.Message)"
        Show-BottomProgress -Message $script:Log -StatusOnly
        [void](Read-Host 'Press Enter to return')
    }
}
