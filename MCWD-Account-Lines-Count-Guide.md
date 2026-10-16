# MCWD Account Lines Count

A PowerShell terminal project guide

## Table of contents

- [Project overview](#project-overview)
- [What the tool provides](#what-the-tool-provides)
- [Connection to Get-MCWD-Adjustments](#connection-to-get-mcwd-adjustments)
- [Input CSV and counting rules](#input-csv-and-counting-rules)
- [Run the script](#run-the-script)
- [Everyday workflow](#everyday-workflow)
- [Keyboard controls and account search](#keyboard-controls-and-account-search)
- [Output CSV and filename](#output-csv-and-filename)
- [Code walkthrough: state and validation](#code-walkthrough-state-and-validation)
- [Code walkthrough: account grouping and line counting](#code-walkthrough-account-grouping-and-line-counting)
- [Code walkthrough: terminal rendering and progress](#code-walkthrough-terminal-rendering-and-progress)
- [Code walkthrough: preview and export](#code-walkthrough-preview-and-export)
- [Function map](#function-map)
- [Errors, checks, and practical limits](#errors-checks-and-practical-limits)
- [Revision notes](#revision-notes)

## Project overview

The MCWD Account Lines Count project is a PowerShell terminal tool for reviewing the number of description lines associated with each account in an adjustment CSV. It helps staff identify accounts that may need a closer look before bill printing.

An account with **8 or more nonblank description lines** is counted as a possible overprint. This is a screening rule: the tool does not calculate how text will wrap on a printed bill.

**Author:** Teo Espero, Marina Coast Water District. Developed with assistance from OpenAI ChatGPT.

**Documented script:** Count-AccountLines.ps1, version 1.14, updated October 16, 2026. The documentation describes the current implementation; interactive Windows terminal behavior has not been independently tested in the development environment.

## What the tool provides

- A terminal workspace with box-drawing borders and highlighted menu selections.
- A file explorer for choosing the input CSV, with parent-folder navigation and pasted paths.
- Automatic processing after a file is selected.
- Account counts and a view limited to possible overprints.
- Full or partial account search, with the descriptions behind each count.
- A preview of the CSV content before export.
- A destination explorer with folders, drive selection, and pasted paths.
- A custom bottom panel for progress and activity status.
- Input validation, source-file protection, and confirmation before replacing an existing report.

The terminal is the application interface. An editor such as VS Code can be used to read or change the script, but is not required to run it.

## Connection to Get-MCWD-Adjustments

This project is a companion to **Get-MCWD-Adjustments.ps1**, the billing adjustment preparation tool. The attached version identifies itself as revision 14.0, dated October 7, 2026.

The preparation tool reads delimited billing exports with numbered columns, selects qualifying Billing transactions, skips blank descriptions, removes identical parsed source rows, and groups eligible descriptions by account and category. It formats account identifiers and calculates amounts before exporting an account-organized report.

The line counter works on that report as a second review step. It reads the exported AccountNumber and Description columns and counts how many nonblank description lines each account contains. It does not repeat the source transaction selection or recalculate adjustment amounts.

| Stage | Tool | Result |
| --- | --- | --- |
| Prepare adjustment report | Get-MCWD-Adjustments.ps1 | Account-organized CSV with AccountNumber, Description, and Amount. |
| Review description length | Count-AccountLines.ps1 | Account line counts and a possible-overprint summary. |
| Review flagged accounts | Staff using the previews | Accounts to inspect against the bill layout before printing. |

The preparation tool writes the account number on the first row of each account block, leaves later account cells blank, and adds an ACCOUNT TOTAL description row. The counter carries the account forward across those blank cells and counts the total row. That shared format is what links the two projects.

```powershell
# Export statement in Get-MCWD-Adjustments.ps1:
$displayRows | Export-Csv -LiteralPath $output -NoTypeInformation -Encoding UTF8
```

Use the **exported by-account CSV** as input to the counter, rather than the raw numbered-column billing export. Duplicate removal happens in the preparation tool; the line counter counts the rows it receives. Keep the exported block order intact.

**Privacy scope:** These guides use fictional account labels and example amounts. The scripts and operational CSV files still contain or display full account identifiers as designed. This documentation update does not mask live previews, change exports, or remove account information from the source project.

## Input CSV and counting rules

The input must contain **AccountNumber** and **Description** columns. Other columns, such as Amount, can remain in the file; the counter does not use them.

```csv
"AccountNumber","Description","Amount"
"DEMO-A","Example water adjustment","1.00"
"","Example water charge","2.00"
"","Example unused description","0.00"
"","ACCOUNT TOTAL","3.00"
```

In this example, all four descriptions belong to account DEMO-A, so its count is **4**.

| Rule | What happens |
| --- | --- |
| Account number is present | It becomes the active account. |
| Account number is blank | The row belongs to the previous active account. |
| Description is blank or whitespace | It adds no lines. |
| Description contains embedded line breaks | Each nonblank line is counted. |
| ACCOUNT TOTAL or NOT USED appears | It counts like any other description. |
| The same account appears in another block | Its lines are added to the existing count. |
| A record is duplicated | It counts again; there is no duplicate removal. |
| Account has at least 8 lines | It is included in the possible-overprint total. |

Keep the input in its original account-block order. Sorting rows with blank account cells can attach descriptions to the wrong account. In production, leading zeros remain in the script's account strings, although spreadsheet software may interpret values differently when opening a CSV.

## Run the script

Use Windows PowerShell 5.1 or PowerShell 7 in an interactive Windows console, such as a Windows Terminal tab. A monospaced font with box-drawing characters gives the intended appearance. Maximize the terminal if panels or previews overlap.

Open PowerShell in the folder containing the script and run:

```powershell
.\Count-AccountLines.ps1
```

To launch it from another folder:

```powershell
& "C:\Tools\Count-AccountLines.ps1"
```

The script uses built-in PowerShell commands and .NET console APIs. No third-party PowerShell module is required. Its saved UTF-8 BOM helps Windows PowerShell 5.1 read the Unicode interface characters.

## Everyday workflow

1. Choose **Browse for a CSV and process it** from the main menu.
2. Open folders with Enter, or choose **Paste a folder or CSV path**.
3. Select the CSV. Processing starts automatically.
4. Watch the bottom panel for loading status, percentage, and processed-record count.
5. Press Enter after processing finishes to return to the menu.
6. Choose **View account counts / possible overprints**, **Preview resulting CSV**, or **Search / preview specific accounts**.
7. Choose **Save CSV report** and navigate to the destination folder.
8. Select **SAVE IN THIS FOLDER**. Confirm replacement only if the destination report already exists.

Saving exports every processed account and the summary. Filtering a preview does not change the exported account list. Reprocess the file after changing its contents; previews and export use the results held in memory.

## Keyboard controls and account search

| Screen | Controls |
| --- | --- |
| Main menu and explorers | Up/Down selects; Enter opens; Esc returns or cancels. |
| Main menu | Select Quit to exit; Esc redraws the main menu. |
| Long menus | Page Up/Page Down moves by a page; Home/End selects first/last. |
| Results | Enter shows all accounts by default; Y limits the view to possible overprints. N/P changes pages; Q returns. |
| CSV preview | N/P changes pages; F/L goes to first/last; Q returns. |
| Account search | Type a full or partial account number; Q returns. |
| Multiple search matches | Type the displayed selection number; N/P pages; Q starts another search. |
| Description preview | N/P changes pages; Q starts another search. |

An exact account match opens directly. Otherwise, the tool searches for a literal substring, so entering DEMO- can find several account suffixes. The description preview shows the contributing lines, the count, the possible-overprint status, and the account's CSV detail row.

Arrow-key highlighting is implemented in the main menu and explorers. Search match selection and preview navigation use typed prompts.

## Output CSV and filename

The report starts with two summary records, a blank record, and an account-detail header. The following is an illustrative two-account report, not a complete production result:

```csv
"Number of accounts:","2"
"Number of accounts with possible overprint:","1"
"",""
"Account #","Lines"
"DEMO-A","4"
"DEMO-B","8"
```

The filename follows **XX-Account Lines Count-TE-YYYYDDMM.csv**.

| Part | Meaning |
| --- | --- |
| XX | Text before the first hyphen in the input filename; not necessarily two digits. |
| Account Lines Count | Report name. |
| TE | Fixed initials in the current implementation. |
| YYYYDDMM | Local computer date: year, day, then month. |

For input XX-MCWD-Adjustments-By-Account.csv saved on October 16, 2026, the name is:

```text
XX-Account Lines Count-TE-20261610.csv
```

The file is a two-column CSV report with summary rows above its detail header. If another program expects a conventional header on the first row, skip the first three report records before importing the detail table. Preview line numbers are not saved. The report is written using PowerShell's UTF8 encoding; BOM behavior differs between Windows PowerShell 5.1 and PowerShell 7.

## Code walkthrough: state and validation

The script keeps the selected path, processed account rows, source descriptions, and current status in script-scoped variables. These values let each screen use the same processing result.

```powershell
$script:InputPath = $null
$script:Results = @()
$script:Descriptions = @{}
```

Import-Csv reads actual CSV fields, so quoted commas and embedded line breaks are handled as CSV content rather than by splitting raw file lines. The code then checks for the required columns:

```powershell
$rows = @(Import-Csv -LiteralPath $script:InputPath)
if ($rows.Count -eq 0) { throw 'The CSV has no data rows.' }
foreach ($column in @('AccountNumber','Description')) {
    if ($column -notin $rows[0].PSObject.Properties.Name) {
        throw "Missing required column: $column"
    }
}
```

LiteralPath prevents wildcard characters in a path from being treated as a filename pattern. The array wrapper keeps the result predictable even when the CSV contains only one data record.

## Code walkthrough: account grouping and line counting

An ordered dictionary holds each account's count in first-seen order. A separate dictionary stores descriptions for account previews. Each nonblank account number updates the active account; blank cells leave that account in place.

```powershell
$nextAccount = ([string]$row.AccountNumber).Trim()
if ($nextAccount) {
    $account = $nextAccount
    if (-not $counts.Contains($account)) {
        $counts[$account] = 0
        $script:Descriptions[$account] = New-Object 'System.Collections.Generic.List[string]'
    }
}
```

Before the following loop, blank descriptions are skipped and a nonblank description without an active account raises an error. The regular expression handles Windows, Unix, and older carriage-return line endings:

```powershell
foreach ($line in ([string]$row.Description -split '
|
|')) {
    if (-not [string]::IsNullOrWhiteSpace($line)) {
        $counts[$account]++
        $script:Descriptions[$account].Add($line)
    }
}
```

The result is a count of explicit nonblank description lines, not a count of physical file lines and not an estimate of printed wrapping. The threshold is inclusive:

```powershell
$overprints = @($script:Results | Where-Object { $_.Lines -ge 8 }).Count
```

A count of 7 is below the threshold; 8 and 9 are possible overprints. The threshold is currently hardcoded in several functions rather than exposed as a setting.

## Code walkthrough: terminal rendering and progress

Get-PanelWidth provides a common content width. Each rendered row adds a border and one padding space on each side. Reserving an unused console column helps avoid automatic wrapping at the right edge.

```powershell
return [Math]::Max(1,[Math]::Min(110,$columns-5))
```

Select-TerminalMenu reads key events without echo, updates the selected index, and repaints from a stable cursor origin. It hides the cursor while navigating and restores visibility in a finally block. The selected row uses a background color:

```powershell
Write-PanelLine ('▶   ' + $label) -ForegroundColor White -BackgroundColor DarkBlue
```

Show-BottomProgress draws a four-row box near the bottom of the visible console. It saves the cursor coordinates and colors, writes each row at an explicit position, and restores the original cursor and colors afterward. This keeps progress from becoming ordinary scrolling output.

```powershell
$savedX = [Console]::CursorLeft
$savedY = [Console]::CursorTop
# Each progress row is written at its own fixed position.
[Console]::SetCursorPosition($left,$top+$i)
[Console]::Write($text)
# The function restores the original position in finally.
[Console]::SetCursorPosition($savedX,$savedY)
```

The counting loop requests roughly 100 progress updates instead of painting after every record:

```powershell
$progressStep = [Math]::Max(1, [int]($rows.Count / 100))
```

The initial import has a loading status but no measured percentage. Set-ActivityStatus reuses the bottom panel for messages such as saving and completion. Some folder validation prompts still appear locally near the input prompt.

## Code walkthrough: preview and export

Get-ReportCsv builds the summary and detail rows once for both preview and export. This avoids maintaining two different report formats. ConvertTo-Csv supplies proper CSV quoting; the automatically generated property header is skipped because the report includes its own detail header after the summary.

```powershell
$report | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1
```

Saving uses the same generator:

```powershell
Get-ReportCsv | Set-Content -LiteralPath $output -Encoding UTF8
```

The destination explorer returns a folder, then Save-Report builds the filename. The source path is checked before writing, and an existing report requires confirmation. Export writes directly to the destination; it does not use a temporary-file replacement or create a backup.

## Function map

| Function | Responsibility |
| --- | --- |
| Get-PanelWidth | Shared content width for boxes. |
| Write-PanelLine / Write-PanelBorder | Text, padding, colors, and borders. |
| Show-Header | Starts a screen and redraws the activity footer. |
| Select-TerminalMenu | Highlighted arrow-key menu and paging. |
| Select-Csv | Input folder and CSV navigation. |
| Show-BottomProgress | Fixed-position progress and activity panel. |
| Set-ActivityStatus | Updates the stored status and bottom display. |
| Invoke-Count | Imports, validates, groups, and counts descriptions. |
| Show-Results | All-account or overprint-only count view. |
| Show-AccountPreview | Account search and contributing descriptions. |
| Get-ReportCsv | Shared report generator. |
| Show-CsvPreview | Paged preview of the export content. |
| Select-SaveFolder | Destination folders, drives, and pasted paths. |
| Save-Report | Destination checks, naming, and writing the report. |

The main loop displays the workspace, dispatches the chosen action, and catches action errors so the user can return to the menu.

## Errors, checks, and practical limits

| Situation | Behavior or action |
| --- | --- |
| Empty CSV or missing required column | Processing stops with an error. |
| Nonblank description before any account | Processing stops rather than guessing an account. |
| Preview or save before processing | The tool asks you to process a CSV first. |
| Inaccessible folder | The browser reports the error and offers navigation again. |
| Existing output file | Replacement requires Y confirmation. |
| Output path equals source path | Saving is blocked. |
| Distorted boxes or overlapping footer | Enlarge the terminal and reopen the screen; fixed preview page sizes can exceed short windows. |
| Unsupported console host or redirected input | Use an interactive Windows console; RawUI and Console cursor APIs are required. |

The entire input and the contributing descriptions are kept in memory. Counting visits the CSV records and their description lines once; practical memory use grows with file size. The tool does not validate billing amounts, remove duplicates, or verify printed layout.

A quick review can use a small CSV with accounts having 7, 8, and 9 lines. Confirm that only the last two count as possible overprints, blank account cells continue the right account, and preview content agrees with the saved report. Also check canceling both explorers and declining an overwrite.

Account identifiers and amounts in this guide are fictional examples. Production account records, screenshots, source paths, and actual account totals are omitted. Windows interactive rendering and end-to-end script execution remain unverified in this environment.

## Revision notes

The script contains authorship, inline comments, and a detailed revision history. The current version is **1.14**.

| Versions | Main changes |
| --- | --- |
| 1.00–1.03 | Initial count/export, file selection, and transition to a terminal interface. |
| 1.04–1.07 | CSV preview, account search, boxed layout, help, and automatic processing. |
| 1.08–1.10 | Keyboard highlighting, destination explorer, and Unicode borders. |
| 1.11–1.14 | Bottom progress, consistent padding, cursor fixes, and activity status footer. |

This document describes the script as supplied on October 16, 2026. Keep the guide and code version together when making later changes.

