<# 04/21/26e
.SYNOPSIS
    Imports UNC source paths from CSV and adds them to CommonMigrationStatus list.

.DESCRIPTION
    Reads a CSV file with UNC parent paths, enumerates subfolders under each,
    extracts DIV and Title from the path structure, adds items to the SharePoint list,
    and creates filtered views for new divisions.
    
    Path parsing examples:
    - CSV: \\contoso-fs\shares\DIV1\Common\ -> Enumerates subfolders
      - \\contoso-fs\shares\DIV1\Common\HR Files -> DIV=DIV1, Title=HR Files
      - \\contoso-fs\shares\DIV1\Common\Archives -> DIV=DIV1, Title=Archives
    - CSV: \\contoso-fs\shares\DIV2\Common\Unit Data\ -> Enumerates subfolders
      - \\contoso-fs\shares\DIV2\Common\Unit Data\Reports -> DIV=DIV2, Title=Reports
    
    Optional CSV columns:
    - OverrideDIV: Forces a specific DIV value instead of auto-parsing from path
      Example: BRANCH1 folder under DIV3 assigned to DIV4 division
    - ExcludeFolders: Semicolon-separated folder names to skip during enumeration
      Example: BRANCH1;Archives skips those subfolders
    
    Features:
    - Enumerates subfolders under each UNC path in CSV
    - Skips "Shortcut" folders (junction points)
    - Auto-extracts DIV (folder after userdata\) or uses OverrideDIV
    - Auto-extracts Title (folder name)
    - Excludes specific subfolders via ExcludeFolders column
    - Checks for existing items to avoid duplicates
    - Creates filtered list views for new divisions
    - SPO throttling protection with exponential backoff
    - Optionally runs c to update navigation

.PARAMETER CSVPath
    Path to CSV file with UNCSource column containing parent folders to scan.
    Default: .\MigrationSources.csv

.PARAMETER EnumerateSubfolders
    When true, enumerates child folders under each UNCSource path.
    When false, uses the UNCSource path directly (no enumeration).
    Default: $true

.PARAMETER SkipDuplicates
    When specified, skips items where SourcePath already exists in the list.
    Default: $true

.PARAMETER CreateViews
    When specified, creates filtered views for new divisions.
    Default: $true

.PARAMETER UpdateLandingPage
    When specified, runs CommonMigrationStatusPage.ps1 after import.
    Default: $true

.PARAMETER WhatIf
    Shows what would be done without making changes.

.EXAMPLE
    .\Import-MigrationSources.ps1 -CSVPath ".\userdata.csv"
    # Enumerates subfolders under each UNC path, imports to list, creates views, updates landing page

.EXAMPLE
    .\Import-MigrationSources.ps1 -CSVPath ".\userdata.csv" -WhatIf
    # Shows what would be imported without making changes

.EXAMPLE
    .\Import-MigrationSources.ps1 -CSVPath ".\userdata.csv" -EnumerateSubfolders:$false
    # Uses CSV paths directly without enumerating subfolders

.NOTES
    Version:     1.2.0
    Date:        2026-04-21
    Author:      Douglas Cox [Microsoft CSA]
    Requires:    PnP.PowerShell module
    Environment: USSec / IL6 (.scloud)
#>

param(
    [string]$CSVPath = ".\MigrationSources.csv",
    [switch]$EnumerateSubfolders = $true,
    [switch]$SkipDuplicates = $true,
    [switch]$CreateViews = $true,
    [switch]$UpdateLandingPage = $true,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# ============================================================
# CONFIGURATION
# ============================================================

$siteUrl  = "https://contoso.spo.microsoft.scloud/sites/000001"
$listName = "CommonMigrationStatus"

# App-Only Authentication
$UseAppAuth               = $true
$AppClientId              = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
$AppTenantId              = "dddddddd-dddd-dddd-dddd-dddddddddddd"
$AppCertificateThumbprint = "1111111111111111111111111111111111111111"

# Throttling settings
$ThrottleRetryCount = 5
$ThrottleBaseWaitSeconds = 15

# Batch settings (pause between items to avoid throttling)
$BatchSize = 25
$BatchPauseSeconds = 3

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "DEBUG"   { "Gray" }
        default   { "White" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Invoke-WithThrottling {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Operation = "Operation"
    )
    
    $retryCount = 0
    while ($retryCount -lt $ThrottleRetryCount) {
        try {
            return & $ScriptBlock
        }
        catch {
            $errorMsg = $_.Exception.Message
            if ($errorMsg -like "*throttled*" -or 
                $errorMsg -like "*429*" -or 
                $errorMsg -like "*503*" -or
                $errorMsg -like "*too many requests*") {
                
                $retryCount++
                $waitTime = $ThrottleBaseWaitSeconds * [Math]::Pow(2, $retryCount - 1)
                Write-Log "Throttled on $Operation - waiting $waitTime seconds (attempt $retryCount/$ThrottleRetryCount)" "WARN"
                Start-Sleep -Seconds $waitTime
            }
            else {
                throw
            }
        }
    }
    throw "Max retries exceeded for $Operation"
}

function Parse-UNCPath {
    param([string]$UNCPath)
    
    # Clean up path
    $path = $UNCPath.Trim().TrimEnd('\')
    
    # Extract DIV - pattern: \\server\share\XXXX\...
    # Example: \\contoso-fs\shares\DIV2\Common\...
    $divMatch = [regex]::Match($path, '\\\\[^\\]+\\[^\\]+\\([^\\]+)')
    $div = if ($divMatch.Success) { $divMatch.Groups[1].Value.ToUpper() } else { "" }
    
    # Extract Title - last folder in path
    $pathParts = $path.Split('\') | Where-Object { $_ -ne "" }
    $title = if ($pathParts.Count -gt 0) { $pathParts[-1] } else { "" }
    
    # Handle paths ending with "Common" (e.g., \\contoso-fs\shares\DIV1\Common\)
    # Title becomes "DIV1 Common" to indicate the entire Common folder
    if ($title -in @("Common", "COMMON", "common")) {
        $title = "$div Common"
    }
    # Handle paths ending with share name (shouldn't happen but just in case)
    elseif ($title -in @("userdata", "UserData", "USERDATA")) {
        $title = $div
    }
    
    return @{
        SourcePath = $path
        DIV = $div
        Title = $title
    }
}

# ============================================================
# MAIN SCRIPT
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   Import Migration Sources" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Validate CSV file exists
if (-not (Test-Path $CSVPath)) {
    Write-Log "CSV file not found: $CSVPath" "ERROR"
    Write-Host ""
    Write-Host "Expected CSV format:" -ForegroundColor Yellow
    Write-Host "  UNCSource,OverrideDIV,ExcludeFolders" -ForegroundColor Gray
    Write-Host "  \\contoso-fs\shares\DIV1\Common\,," -ForegroundColor Gray
    Write-Host "  \\contoso-fs\shares\DIV3\COMMON\,,BRANCH1" -ForegroundColor Gray
    Write-Host "  \\contoso-fs\shares\DIV3\COMMON\BRANCH1,DIV4," -ForegroundColor Gray
    Write-Host "" -ForegroundColor Gray
    Write-Host "Optional columns:" -ForegroundColor Yellow
    Write-Host "  OverrideDIV    - Forces DIV value (e.g., assign BRANCH1 to DIV4)" -ForegroundColor Gray
    Write-Host "  ExcludeFolders - Semicolon-separated names to skip (e.g., BRANCH1;Archives)" -ForegroundColor Gray
    Write-Host "" -ForegroundColor Gray
    Write-Host "Each path will be scanned for subfolders (each subfolder = 1 list item)" -ForegroundColor Gray
    exit 1
}

# Read CSV
Write-Log "Reading CSV: $CSVPath"
$csvData = Import-Csv -Path $CSVPath

# Check for UNCSource column (or FullName for backward compatibility)
$sourceColumn = if ($csvData[0].PSObject.Properties.Name -contains "UNCSource") { "UNCSource" }
                elseif ($csvData[0].PSObject.Properties.Name -contains "FullName") { "FullName" }
                elseif ($csvData[0].PSObject.Properties.Name -contains "SourcePath") { "SourcePath" }
                else { $null }

if (-not $sourceColumn) {
    Write-Log "CSV must have 'UNCSource', 'FullName', or 'SourcePath' column" "ERROR"
    exit 1
}

Write-Log "Found $($csvData.Count) rows using column: $sourceColumn" "SUCCESS"

# Enumerate subfolders or use paths directly
Write-Log "Scanning UNC paths for subfolders..."
$parsedItems = @()
$skippedFolders = @()

foreach ($row in $csvData) {
    $parentPath = $row.$sourceColumn
    if ([string]::IsNullOrWhiteSpace($parentPath)) { continue }
    
    $parentPath = $parentPath.Trim().TrimEnd('\')
    
    # Get optional columns
    $overrideDIV = if ($row.PSObject.Properties.Name -contains "OverrideDIV" -and $row.OverrideDIV) { 
        $row.OverrideDIV.Trim().ToUpper() 
    } else { $null }
    
    $excludeList = @()
    if ($row.PSObject.Properties.Name -contains "ExcludeFolders" -and $row.ExcludeFolders) {
        $excludeList = $row.ExcludeFolders.Split(';') | ForEach-Object { $_.Trim().ToUpper() } | Where-Object { $_ }
    }
    
    if ($EnumerateSubfolders) {
        # Enumerate child directories under this path (works at any depth)
        Write-Log "Scanning: $parentPath" "DEBUG"
        if ($excludeList.Count -gt 0) {
            Write-Log "  Excluding: $($excludeList -join ', ')" "DEBUG"
        }
        
        try {
            if (-not (Test-Path $parentPath)) {
                Write-Log "Path not accessible: $parentPath" "WARN"
                continue
            }
            
            $childFolders = Get-ChildItem -Path $parentPath -Directory -ErrorAction Stop
            $addedFromPath = 0
            
            foreach ($folder in $childFolders) {
                # Skip Shortcut folders (junction points) and system folders
                if ($folder.Name -like "*Shortcut*" -or 
                    $folder.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                    $skippedFolders += $folder.FullName
                    Write-Log "  Skipping (shortcut/junction): $($folder.Name)" "DEBUG"
                    continue
                }
                
                # Skip folders in exclude list
                if ($folder.Name.ToUpper() -in $excludeList) {
                    $skippedFolders += $folder.FullName
                    Write-Log "  Skipping (excluded): $($folder.Name)" "DEBUG"
                    continue
                }
                
                $parsed = Parse-UNCPath -UNCPath $folder.FullName
                # Apply DIV override if specified
                if ($overrideDIV) {
                    $parsed.DIV = $overrideDIV
                }
                if ($parsed.DIV -and $parsed.Title) {
                    $parsedItems += [PSCustomObject]$parsed
                    $addedFromPath++
                }
            }
            
            # If no subfolders found, add the parent path itself (it's a leaf folder)
            if ($childFolders.Count -eq 0) {
                Write-Log "  No subfolders found - adding path itself" "DEBUG"
                $parsed = Parse-UNCPath -UNCPath $parentPath
                # Apply DIV override if specified
                if ($overrideDIV) {
                    $parsed.DIV = $overrideDIV
                }
                if ($parsed.DIV -and $parsed.Title) {
                    $parsedItems += [PSCustomObject]$parsed
                    $addedFromPath = 1
                }
            }
            
            Write-Log "  Found $addedFromPath items from: $parentPath" "SUCCESS"
        }
        catch {
            Write-Log "Error scanning $parentPath`: $($_.Exception.Message)" "ERROR"
        }
    }
    else {
        # Use path directly (no enumeration)
        $parsed = Parse-UNCPath -UNCPath $parentPath
        # Apply DIV override if specified
        if ($overrideDIV) {
            $parsed.DIV = $overrideDIV
        }
        if ($parsed.DIV -and $parsed.Title) {
            $parsedItems += [PSCustomObject]$parsed
        }
        else {
            Write-Log "Could not parse: $parentPath" "WARN"
        }
    }
}

if ($skippedFolders.Count -gt 0) {
    Write-Log "Skipped $($skippedFolders.Count) shortcut/junction folders" "WARN"
}

Write-Log "Found $($parsedItems.Count) folders to import" "SUCCESS"

# Show preview
Write-Host ""
Write-Host "Preview (first 5 items):" -ForegroundColor Cyan
$parsedItems | Select-Object -First 5 | Format-Table DIV, Title, SourcePath -AutoSize

# Get unique DIVs
$uniqueDivs = $parsedItems | Select-Object -ExpandProperty DIV -Unique | Sort-Object
Write-Log "Unique divisions: $($uniqueDivs -join ', ')"

if ($WhatIf) {
    Write-Host ""
    Write-Host "=== WHATIF MODE - No changes will be made ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Would add $($parsedItems.Count) items to list" -ForegroundColor Yellow
    Write-Host "Would check/create views for: $($uniqueDivs -join ', ')" -ForegroundColor Yellow
    exit 0
}

# ============================================================
# CONNECT TO SHAREPOINT
# ============================================================

Write-Host ""
Write-Log "Connecting to SharePoint..."

try {
    if ($UseAppAuth) {
        Connect-PnPOnline -Url $siteUrl `
            -ClientId $AppClientId `
            -Tenant $AppTenantId `
            -Thumbprint $AppCertificateThumbprint `
            -ErrorAction Stop
    } else {
        Connect-PnPOnline -Url $siteUrl -UseWebLogin -ErrorAction Stop
    }
    Write-Log "Connected to $siteUrl" "SUCCESS"
}
catch {
    Write-Log "Failed to connect: $($_.Exception.Message)" "ERROR"
    exit 1
}

# ============================================================
# GET EXISTING DATA
# ============================================================

Write-Log "Loading existing list data..."

# Get existing SourcePaths to check for duplicates
$existingItems = Invoke-WithThrottling -Operation "Get list items" -ScriptBlock {
    Get-PnPListItem -List $listName -PageSize 500 -Fields "SourcePath", "DIV" -ErrorAction Stop
}

$existingPaths = @{}
$existingDivs = @{}
foreach ($item in $existingItems) {
    $sp = if ($item["SourcePath"]) { $item["SourcePath"].ToString().Trim().ToLower() } else { "" }
    if ($sp) { $existingPaths[$sp] = $true }
    
    $div = if ($item["DIV"]) { $item["DIV"].ToString().Trim().ToUpper() } else { "" }
    if ($div) { $existingDivs[$div] = $true }
}

Write-Log "Found $($existingPaths.Count) existing items, $($existingDivs.Count) existing divisions" "SUCCESS"

# Get existing views
Write-Log "Checking existing list views..."
$existingViews = Invoke-WithThrottling -Operation "Get views" -ScriptBlock {
    Get-PnPView -List $listName -ErrorAction Stop
}
$viewNames = $existingViews | ForEach-Object { $_.Title }
Write-Log "Found $($viewNames.Count) existing views" "SUCCESS"

# ============================================================
# ADD ITEMS TO LIST
# ============================================================

Write-Host ""
Write-Log "Adding items to list..."

$added = 0
$skipped = 0
$failed = 0
$newDivs = @{}
$itemCount = 0

foreach ($item in $parsedItems) {
    $itemCount++
    
    # Check for duplicate
    $pathLower = $item.SourcePath.ToLower()
    if ($SkipDuplicates -and $existingPaths.ContainsKey($pathLower)) {
        $skipped++
        Write-Log "[$itemCount/$($parsedItems.Count)] SKIP (exists): $($item.Title)" "DEBUG"
        continue
    }
    
    # Track new DIVs
    if (-not $existingDivs.ContainsKey($item.DIV)) {
        $newDivs[$item.DIV] = $true
    }
    
    # Add to list
    try {
        Invoke-WithThrottling -Operation "Add item $($item.Title)" -ScriptBlock {
            Add-PnPListItem -List $listName -Values @{
                "Title"      = $item.Title
                "DIV"        = $item.DIV
                "SourcePath" = $item.SourcePath
            } -ErrorAction Stop | Out-Null
        }
        
        $added++
        $existingPaths[$pathLower] = $true  # Track for subsequent duplicates in same batch
        Write-Log "[$itemCount/$($parsedItems.Count)] ADDED: $($item.DIV) - $($item.Title)" "SUCCESS"
    }
    catch {
        $failed++
        Write-Log "[$itemCount/$($parsedItems.Count)] FAILED: $($item.Title) - $($_.Exception.Message)" "ERROR"
    }
    
    # Batch pause to avoid throttling
    if ($itemCount % $BatchSize -eq 0) {
        Write-Log "Pausing $BatchPauseSeconds seconds (batch checkpoint)..." "DEBUG"
        Start-Sleep -Seconds $BatchPauseSeconds
    }
}

Write-Host ""
Write-Log "Import complete: Added=$added, Skipped=$skipped, Failed=$failed" "SUCCESS"

# ============================================================
# CREATE VIEWS FOR NEW DIVISIONS
# ============================================================

if ($CreateViews -and $newDivs.Count -gt 0) {
    Write-Host ""
    Write-Log "Creating views for $($newDivs.Count) new division(s)..."
    
    # Get default view's fields to use for new views
    $defaultView = $existingViews | Where-Object { $_.DefaultView -eq $true } | Select-Object -First 1
    $defaultViewFields = if ($defaultView) { 
        $defaultView.ViewFields 
    } else { 
        @("Title", "DIV", "SourcePath")  # Fallback if no default found
    }
    Write-Log "Using fields from default view: $($defaultViewFields -join ', ')" "DEBUG"
    
    foreach ($div in ($newDivs.Keys | Sort-Object)) {
        $viewName = $div
        
        # Check if view already exists
        if ($viewName -in $viewNames) {
            Write-Log "View '$viewName' already exists - skipping" "DEBUG"
            continue
        }
        
        try {
            # Create filtered view with same fields as default view
            $camlQuery = "<Where><Eq><FieldRef Name='DIV'/><Value Type='Text'>$div</Value></Eq></Where>"
            
            Invoke-WithThrottling -Operation "Create view $viewName" -ScriptBlock {
                Add-PnPView -List $listName `
                    -Title $viewName `
                    -Fields $defaultViewFields `
                    -Query $camlQuery `
                    -RowLimit 30 `
                    -Paged `
                    -ErrorAction Stop | Out-Null
            }
            
            Write-Log "Created view: $viewName.aspx" "SUCCESS"
        }
        catch {
            Write-Log "Failed to create view '$viewName': $($_.Exception.Message)" "ERROR"
        }
    }
}

# ============================================================
# UPDATE LANDING PAGE
# ============================================================

if ($UpdateLandingPage -and ($added -gt 0 -or $newDivs.Count -gt 0)) {
    Write-Host ""
    Write-Log "Updating landing page..."
    
    $landingPageScript = Join-Path $PSScriptRoot "CommonMigrationStatusPage.ps1"
    
    if (Test-Path $landingPageScript) {
        try {
            # Disconnect first to avoid connection conflicts
            Disconnect-PnPOnline -ErrorAction SilentlyContinue
            
            & $landingPageScript
            Write-Log "Landing page updated" "SUCCESS"
        }
        catch {
            Write-Log "Failed to update landing page: $($_.Exception.Message)" "WARN"
            Write-Log "Run CommonMigrationStatusPage.ps1 manually" "WARN"
        }
    }
    else {
        Write-Log "Landing page script not found: $landingPageScript" "WARN"
        Write-Log "Run CommonMigrationStatusPage.ps1 manually to add new divisions" "WARN"
    }
}
else {
    Disconnect-PnPOnline -ErrorAction SilentlyContinue
}

# ============================================================
# SUMMARY
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   IMPORT COMPLETE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Items Added:   $added" -ForegroundColor White
Write-Host "  Items Skipped: $skipped (duplicates)" -ForegroundColor White
Write-Host "  Items Failed:  $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "White" })
if ($newDivs.Count -gt 0) {
    Write-Host "  New Divisions: $($newDivs.Keys -join ', ')" -ForegroundColor Green
}
Write-Host "============================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    Write-Host ""
    Write-Host "Some items failed - check output above for details" -ForegroundColor Yellow
}
