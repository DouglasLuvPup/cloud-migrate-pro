<# 04/07/26a
.SYNOPSIS
    Retries failed migrations from SPMT reports (ItemReport, ItemFailureReport, or FailureSummaryReport2).
    Deletes source files ONLY after successful upload with content verification.

.DESCRIPTION
    This script combines the best features of Uploadp1 (filename sanitization) and 
    Uploadp2 (folder creation, 0-byte detection, retry logic) specifically for
    retrying failed CommonDriveMigration items.

    Supported CSV formats:
    - ItemReport_R1.csv         (SPMT main report - has Destination column)
    - ItemFailureReport_*.csv   (SPMT failure report - has Destination column)
    - FailureSummaryReport2.csv (CommonDriveMigration summary - needs -SiteUrl param)

    Key Features:
    - Reads failed/skipped items from any SPMT report CSV
    - Creates missing target folders before upload
    - Detects and replaces 0-byte files (partial uploads)
    - Verifies upload succeeded with content before source deletion
    - Sanitizes filenames for SPO compliance
    - Comprehensive logging

.PARAMETER CsvPath
    Path to SPMT report CSV (ItemReport_*.csv, ItemFailureReport_*.csv, or FailureSummaryReport2.csv)

.PARAMETER SiteUrl
    Target site URL (required for FailureSummaryReport2.csv, optional for ItemReport)

.PARAMETER TargetLibrary
    Target library name. Default: "Shared Documents"

.PARAMETER TargetSubfolder
    Subfolder within the library (e.g., "General" for Teams channel). Optional.

.PARAMETER DeleteSource
    When specified, deletes source files after successful upload.

.PARAMETER LogPath
    Path for output log CSV. Default: auto-generated next to input CSV.

.PARAMETER WhatIf
    Show what would happen without making changes.

.EXAMPLE
    .\Retry-FailedMigration.ps1 -CsvPath "F:\SPMTLOGS\task1\FailureSummaryReport2.csv" -SiteUrl "https://contoso.spo.microsoft.scloud/sites/TeamSite" -TargetSubfolder "General" -DeleteSource

.EXAMPLE
    # Using ItemReport which has Destination column
    .\Retry-FailedMigration.ps1 -CsvPath "F:\SPMTLOGS\task1\TaskReport_xyz\ItemReport_R1.csv" -DeleteSource

.NOTES
    Author: Douglas Cox [Microsoft CSA]
    Version: 1.0.0
    Environment: USSec / IL6

    File is deleted from source ONLY when:
    1. Upload completes without error
    2. Target file exists
    3. Target file size > 0 bytes
    4. Target file size matches source file size (within tolerance)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$CsvPath,

    [Parameter(Mandatory=$false)]
    [string]$SiteUrl,

    [Parameter(Mandatory=$false)]
    [string]$TargetLibrary = "Shared Documents",

    [Parameter(Mandatory=$false)]
    [string]$TargetSubfolder = "",

    [Parameter(Mandatory=$false)]
    [string]$LogPath,

    [switch]$DeleteSource,
    [switch]$WhatIf
)

#Requires -Modules PnP.PowerShell

$ErrorActionPreference = "Continue"
$scriptVersion = "1.0.0"

# SPO compliance settings
$ReservedNames = @("CON", "PRN", "AUX", "NUL", "COM0", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT0", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9")
$MaxPathLength = 400
$MaxSegmentLength = 255

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Write-Log {
    param(
        [string]$Message,
        [string]$Type = "INFO",
        [string]$Source = "",
        [string]$Target = "",
        [string]$Action = ""
    )
    
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$ts [$Type] $Message"
    
    switch ($Type) {
        "ERROR"   { Write-Host $line -ForegroundColor Red }
        "WARNING" { Write-Host $line -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $line -ForegroundColor Green }
        "DELETE"  { Write-Host $line -ForegroundColor Magenta }
        default   { Write-Host $line }
    }
    
    if ($script:LogPath) {
        $esc = { param($s) if ($s) { $s -replace '"','""' } else { "" } }
        $csvLine = "`"$ts`",`"$Type`",`"$(&$esc $Source)`",`"$(&$esc $Target)`",`"$(&$esc $Action)`",`"$(&$esc $Message)`""
        Add-Content -Path $script:LogPath -Value $csvLine
    }
}

function Get-SafeFileName {
    param([string]$fileName)
    
    $safeName = $fileName
    $issues = @()
    
    # Replace invalid characters
    $invalidChars = '["\*:<>\?/\\|]'
    if ($safeName -match $invalidChars) {
        $safeName = $safeName -replace $invalidChars, '_'
        $issues += "Invalid chars replaced"
    }
    
    # Trim leading/trailing spaces and dots
    $trimmed = $safeName.Trim(' .')
    if ($trimmed -ne $safeName) {
        $safeName = $trimmed
        $issues += "Trimmed spaces/dots"
    }
    
    # Handle reserved names
    $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($safeName)
    if ($nameWithoutExt.ToUpper() -in $ReservedNames) {
        $extension = [System.IO.Path]::GetExtension($safeName)
        $safeName = $nameWithoutExt + "_file" + $extension
        $issues += "Reserved name fixed"
    }
    
    # Handle _vti_ pattern
    if ($safeName -match '_vti_') {
        $safeName = $safeName -replace '_vti_', '_vti-'
        $issues += "SPO pattern fixed"
    }
    
    # Handle temp file pattern
    if ($safeName -match '^~\$') {
        $safeName = $safeName -replace '^~\$', 'temp_'
        $issues += "Temp pattern fixed"
    }
    
    # Truncate if too long
    if ($safeName.Length -gt $MaxSegmentLength) {
        $extension = [System.IO.Path]::GetExtension($safeName)
        $nameOnly = [System.IO.Path]::GetFileNameWithoutExtension($safeName)
        $maxNameLength = $MaxSegmentLength - $extension.Length - 1
        if ($maxNameLength -gt 10) {
            $safeName = $nameOnly.Substring(0, $maxNameLength) + $extension
            $issues += "Truncated"
        }
    }
    
    return @{
        SafeName = $safeName
        Issues = $issues -join "; "
        Changed = ($safeName -ne $fileName)
    }
}

function Ensure-FolderPath {
    param([string]$FolderRelativePath)
    
    $rel = $FolderRelativePath.Trim('/').Replace('\', '/')
    if ([string]::IsNullOrWhiteSpace($rel)) { return $true }
    
    $parts = $rel -split '/'
    if ($parts.Count -eq 0) { return $true }
    
    $current = $parts[0]  # Library name
    
    for ($i = 1; $i -lt $parts.Count; $i++) {
        $parent = $current
        $leaf = $parts[$i]
        
        try {
            $existing = Get-PnPFolder -Url $current -ErrorAction SilentlyContinue
            if (-not $existing) {
                Add-PnPFolder -Folder $parent -Name $leaf -ErrorAction Stop | Out-Null
                Write-Log "Created folder: $leaf in $parent" "INFO"
            }
        }
        catch {
            # Folder might already exist, continue
        }
        $current = "$current/$leaf"
    }
    
    return $true
}

function Get-FileSizeBytes {
    param([string]$SiteRelativeUrl)
    
    try {
        $file = Get-PnPFile -Url $SiteRelativeUrl -AsListItem -ErrorAction SilentlyContinue
        if ($file) {
            if ($file.FieldValues.ContainsKey("File_x0020_Size")) {
                return [int64]$file.FieldValues["File_x0020_Size"]
            }
            # Alternative field name
            if ($file.FieldValues.ContainsKey("SMTotalFileStreamSize")) {
                return [int64]$file.FieldValues["SMTotalFileStreamSize"]
            }
        }
        return $null
    }
    catch {
        return $null
    }
}

function Test-FileExists {
    param([string]$SiteRelativeUrl)
    
    try {
        $file = Get-PnPFile -Url $SiteRelativeUrl -ErrorAction SilentlyContinue
        return ($null -ne $file)
    }
    catch {
        return $false
    }
}

# ============================================================
# MAIN SCRIPT
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Retry-FailedMigration v$scriptVersion" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Validate CSV exists
if (-not (Test-Path -LiteralPath $CsvPath)) {
    Write-Host "ERROR: CSV not found: $CsvPath" -ForegroundColor Red
    exit 1
}

# Setup log file
if (-not $LogPath) {
    $csvDir = [IO.Path]::GetDirectoryName($CsvPath)
    $csvBase = [IO.Path]::GetFileNameWithoutExtension($CsvPath)
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $LogPath = Join-Path $csvDir "RetryMigration_${csvBase}_$timestamp.csv"
}
$script:LogPath = $LogPath

# Initialize log with headers
Set-Content -Path $LogPath -Value 'Timestamp,Type,Source,Target,Action,Message'

Write-Log "Script started - v$scriptVersion"
Write-Log "Input CSV: $CsvPath"
Write-Log "Delete Source: $DeleteSource"
if ($WhatIf) { Write-Log "Running in WhatIf mode - no changes will be made" "WARNING" }

# Import CSV and detect format
try {
    $rows = Import-Csv -Path $CsvPath
    $totalRows = ($rows | Measure-Object).Count
    
    if ($totalRows -eq 0) {
        Write-Log "CSV is empty" "WARNING"
        exit 0
    }
    
    $first = $rows | Select-Object -First 1
    $columns = $first.PSObject.Properties.Name
    
    # Detect CSV format
    $hasDestination = $columns -contains "Destination"
    $hasSource = $columns -contains "Source"
    $hasStatus = $columns -contains "Status"
    
    Write-Log "CSV format detected: Destination=$hasDestination, Source=$hasSource, Status=$hasStatus"
    
    if (-not $hasSource) {
        Write-Log "CSV must contain 'Source' column" "ERROR"
        exit 1
    }
    
    # If no Destination column, require SiteUrl parameter
    if (-not $hasDestination -and [string]::IsNullOrWhiteSpace($SiteUrl)) {
        Write-Log "CSV has no 'Destination' column - you must provide -SiteUrl parameter" "ERROR"
        exit 1
    }
}
catch {
    Write-Log "Failed to read CSV: $($_.Exception.Message)" "ERROR"
    exit 1
}

# Filter for failed/skipped items only
$failedRows = $rows | Where-Object { 
    $_.Status -eq "failed" -or 
    $_.Status -eq "skipped" -or 
    $_.Status -eq "FatalError" -or
    $_.Status -eq "FAILED"  # Support different case conventions
}

$failedCount = ($failedRows | Measure-Object).Count
Write-Log "Found $failedCount failed/skipped items out of $totalRows total"

if ($failedCount -eq 0) {
    Write-Log "No failed items to process" "SUCCESS"
    exit 0
}

# Group by target site
$bySite = @{}

foreach ($row in $failedRows) {
    $sourcePath = $row.Source
    
    # Skip if source doesn't exist
    if (-not (Test-Path -LiteralPath $sourcePath -ErrorAction SilentlyContinue)) {
        Write-Log "Source not found (may have been deleted): $sourcePath" "WARNING" $sourcePath "" "SKIP"
        continue
    }
    
    # Determine target site and path
    $targetSite = $SiteUrl
    $targetPath = ""
    
    if ($hasDestination -and $row.Destination) {
        # Parse Destination URL to extract site and path
        $dest = $row.Destination.Trim()
        
        if ($dest -match '^(https://[^/]+/(?:sites|teams|personal)/[^/]+)(.*)$') {
            $targetSite = $Matches[1]
            $targetPath = $Matches[2].TrimStart('/')
        }
        elseif ($dest -match '^(https://[^/]+)(.*)$') {
            $targetSite = $Matches[1]
            $targetPath = $Matches[2].TrimStart('/')
        }
    }
    else {
        # Build target path from source structure
        # Extract relative path from source (after common drive root)
        $sourceName = [IO.Path]::GetFileName($sourcePath)
        
        # Build target path
        if ($TargetSubfolder) {
            $targetPath = "$TargetLibrary/$TargetSubfolder/$sourceName"
        }
        else {
            $targetPath = "$TargetLibrary/$sourceName"
        }
    }
    
    if ([string]::IsNullOrWhiteSpace($targetSite)) {
        Write-Log "Could not determine target site for: $sourcePath" "ERROR" $sourcePath "" "SKIP"
        continue
    }
    
    # Add to site group
    if (-not $bySite.ContainsKey($targetSite)) {
        $bySite[$targetSite] = [System.Collections.ArrayList]::new()
    }
    
    [void]$bySite[$targetSite].Add([PSCustomObject]@{
        SourcePath = $sourcePath
        TargetPath = $targetPath.Replace('\', '/')
        Row = $row
    })
}

# Process by site
$stats = @{
    Success = 0
    Failed = 0
    Skipped = 0
    Deleted = 0
}

foreach ($site in $bySite.Keys) {
    Write-Host ""
    Write-Log "Connecting to: $site"
    
    if (-not $WhatIf) {
        try {
            Connect-PnPOnline -Url $site -UseWebLogin -ErrorAction Stop
        }
        catch {
            try {
                Connect-PnPOnline -Url $site -Interactive -ErrorAction Stop
            }
            catch {
                Write-Log "Connection failed: $($_.Exception.Message)" "ERROR"
                foreach ($item in $bySite[$site]) {
                    Write-Log "Skipped due to connection failure" "ERROR" $item.SourcePath $item.TargetPath "SKIP"
                    $stats.Failed++
                }
                continue
            }
        }
    }
    
    foreach ($item in $bySite[$site]) {
        $sourcePath = $item.SourcePath
        $targetPath = $item.TargetPath
        
        Write-Host ""
        Write-Host "Processing: $sourcePath" -ForegroundColor Cyan
        Write-Host "  Target: $targetPath" -ForegroundColor Gray
        
        # Validate source exists and get size
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            Write-Log "Source file not found" "ERROR" $sourcePath $targetPath "SKIP"
            $stats.Failed++
            continue
        }
        
        $sourceFile = Get-Item -LiteralPath $sourcePath
        $sourceSize = $sourceFile.Length
        
        # Check if it's a file (not directory)
        if ($sourceFile.PSIsContainer) {
            Write-Log "Source is a directory, not a file - skipping" "WARNING" $sourcePath $targetPath "SKIP"
            $stats.Skipped++
            continue
        }
        
        # Sanitize filename
        $originalName = $sourceFile.Name
        $safeResult = Get-SafeFileName -fileName $originalName
        $fileName = $safeResult.SafeName
        
        if ($safeResult.Changed) {
            Write-Log "Filename sanitized: $originalName -> $fileName ($($safeResult.Issues))" "WARNING" $sourcePath $targetPath "SANITIZE"
        }
        
        # Determine folder path and full target
        $folderPath = Split-Path $targetPath -Parent
        if ([string]::IsNullOrWhiteSpace($folderPath) -or $folderPath -eq ".") {
            $folderPath = $TargetLibrary
        }
        $folderPath = $folderPath.Replace('\', '/')
        
        $fullTargetPath = "$folderPath/$fileName"
        
        # Check path length
        if ($fullTargetPath.Length -gt $MaxPathLength) {
            Write-Log "Target path too long ($($fullTargetPath.Length) chars)" "ERROR" $sourcePath $fullTargetPath "SKIP"
            $stats.Failed++
            continue
        }
        
        if ($WhatIf) {
            Write-Log "WhatIf: Would upload to $fullTargetPath" "WARNING" $sourcePath $fullTargetPath "WHATIF"
            if ($DeleteSource) {
                Write-Log "WhatIf: Would delete source after successful upload" "WARNING" $sourcePath $fullTargetPath "WHATIF"
            }
            $stats.Success++
            continue
        }
        
        # Ensure target folder exists
        try {
            Ensure-FolderPath -FolderRelativePath $folderPath
        }
        catch {
            Write-Log "Failed to create folder: $($_.Exception.Message)" "ERROR" $sourcePath $folderPath "FOLDER_ERROR"
        }
        
        # Check if file already exists
        $existingSize = Get-FileSizeBytes -SiteRelativeUrl $fullTargetPath
        
        if ($null -ne $existingSize) {
            if ($existingSize -eq 0) {
                # 0-byte file exists - delete and re-upload
                Write-Log "Found 0-byte file at target - will replace" "WARNING" $sourcePath $fullTargetPath "REPLACE_ZERO"
                try {
                    Remove-PnPFile -SiteRelativeUrl $fullTargetPath -Force -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Log "Could not remove 0-byte file: $($_.Exception.Message)" "WARNING" $sourcePath $fullTargetPath "WARN"
                }
            }
            elseif ($existingSize -eq $sourceSize) {
                # File exists with matching size - skip upload, but allow deletion of source
                Write-Log "File already exists with matching size ($existingSize bytes)" "SUCCESS" $sourcePath $fullTargetPath "SKIP_UPLOAD"
                $stats.Success++
                
                # Delete source if requested and file matches
                if ($DeleteSource) {
                    try {
                        Remove-Item -LiteralPath $sourcePath -Force -ErrorAction Stop
                        Write-Log "Source deleted (file already at destination)" "DELETE" $sourcePath $fullTargetPath "DELETED"
                        $stats.Deleted++
                    }
                    catch {
                        Write-Log "Failed to delete source: $($_.Exception.Message)" "ERROR" $sourcePath $fullTargetPath "DELETE_ERROR"
                    }
                }
                continue
            }
            else {
                # Different size - skip (don't overwrite)
                Write-Log "File exists with different size (source: $sourceSize, target: $existingSize) - skipping" "WARNING" $sourcePath $fullTargetPath "SIZE_MISMATCH"
                $stats.Skipped++
                continue
            }
        }
        
        # Upload file
        try {
            Add-PnPFile -Path $sourcePath -Folder $folderPath -NewFileName $fileName -ErrorAction Stop | Out-Null
            Write-Log "Upload successful" "SUCCESS" $sourcePath $fullTargetPath "UPLOADED"
        }
        catch {
            Write-Log "Upload failed: $($_.Exception.Message)" "ERROR" $sourcePath $fullTargetPath "UPLOAD_ERROR"
            $stats.Failed++
            continue
        }
        
        # Verify upload
        Start-Sleep -Milliseconds 500  # Brief wait for SPO to finalize
        
        $uploadedSize = Get-FileSizeBytes -SiteRelativeUrl $fullTargetPath
        
        if ($null -eq $uploadedSize) {
            Write-Log "Could not verify upload - file not found at target" "ERROR" $sourcePath $fullTargetPath "VERIFY_ERROR"
            $stats.Failed++
            continue
        }
        
        if ($uploadedSize -eq 0) {
            Write-Log "Upload resulted in 0-byte file - NOT deleting source" "ERROR" $sourcePath $fullTargetPath "ZERO_BYTE"
            $stats.Failed++
            continue
        }
        
        # Allow small tolerance for metadata differences
        $sizeDiff = [Math]::Abs($uploadedSize - $sourceSize)
        $tolerance = [Math]::Max(1024, $sourceSize * 0.001)  # 0.1% or 1KB, whichever is larger
        
        if ($sizeDiff -gt $tolerance) {
            Write-Log "Size mismatch after upload (source: $sourceSize, uploaded: $uploadedSize) - NOT deleting source" "WARNING" $sourcePath $fullTargetPath "SIZE_VERIFY"
            $stats.Success++  # Upload technically succeeded
            continue
        }
        
        $stats.Success++
        Write-Log "Upload verified ($uploadedSize bytes)" "SUCCESS" $sourcePath $fullTargetPath "VERIFIED"
        
        # Delete source if requested
        if ($DeleteSource) {
            try {
                Remove-Item -LiteralPath $sourcePath -Force -ErrorAction Stop
                Write-Log "Source deleted after verified upload" "DELETE" $sourcePath $fullTargetPath "DELETED"
                $stats.Deleted++
            }
            catch {
                Write-Log "Failed to delete source: $($_.Exception.Message)" "ERROR" $sourcePath $fullTargetPath "DELETE_ERROR"
            }
        }
    }
    
    # Disconnect
    try { Disconnect-PnPOnline -ErrorAction SilentlyContinue } catch { }
}

# Summary
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  RETRY MIGRATION COMPLETE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Successful: $($stats.Success)" -ForegroundColor Green
Write-Host "  Failed:     $($stats.Failed)" -ForegroundColor $(if ($stats.Failed -gt 0) { "Red" } else { "Green" })
Write-Host "  Skipped:    $($stats.Skipped)" -ForegroundColor $(if ($stats.Skipped -gt 0) { "Yellow" } else { "Green" })
if ($DeleteSource) {
    Write-Host "  Deleted:    $($stats.Deleted)" -ForegroundColor Magenta
}
Write-Host ""
Write-Host "  Log: $LogPath" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Cyan

Write-Log "Script complete. Success=$($stats.Success), Failed=$($stats.Failed), Skipped=$($stats.Skipped), Deleted=$($stats.Deleted)"
